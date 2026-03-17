import Foundation
import UniformTypeIdentifiers

@MainActor
final class GameAdvancedSettingsViewModel: ObservableObject {

    // MARK: - Dependencies

    private let selectedGameManager: SelectedGameManager
    private var gameRepository: GameRepository?

    // MARK: - Output (UI state)

    @Published var memoryRange: ClosedRange<Double>
    @Published var selectedGarbageCollector: GarbageCollector
    @Published var optimizationPreset: OptimizationPreset
    @Published var customJvmArguments: String
    @Published var environmentVariables: String
    @Published var javaPath: String
    @Published var javaVersionInfo: String
    @Published var error: GlobalError?
    @Published var isLoadingSettings: Bool

    // MARK: - Internal optimization flags (derived / persisted into JVM args)

    private var enableOptimizations: Bool = true
    private var enableAikarFlags: Bool = false
    private var enableMemoryOptimizations: Bool = true
    private var enableThreadOptimizations: Bool = true
    private var enableNetworkOptimizations: Bool = false

    private var saveTask: Task<Void, Never>?

    // MARK: - Init

    init(selectedGameManager: SelectedGameManager = .shared) {
        self.selectedGameManager = selectedGameManager
        self.memoryRange = Double(GameSettingsManager.shared.globalXms)...Double(GameSettingsManager.shared.globalXmx)
        self.selectedGarbageCollector = .g1gc
        self.optimizationPreset = .balanced
        self.customJvmArguments = ""
        self.environmentVariables = ""
        self.javaPath = ""
        self.javaVersionInfo = ""
        self.error = nil
        self.isLoadingSettings = false
    }

    // MARK: - Derived

    var currentGame: GameVersionInfo? {
        guard let gameId = selectedGameManager.selectedGameId else { return nil }
        return gameRepository?.getGame(by: gameId)
    }

    /// 是否使用自定义JVM参数（与垃圾回收器和性能优化互斥）
    var isUsingCustomArguments: Bool {
        !customJvmArguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 当前生效的 Java 路径（优先使用本地修改，其次为存储在游戏配置中的路径）
    var effectiveJavaPath: String {
        if !javaPath.isEmpty {
            return javaPath
        }
        return currentGame?.javaPath ?? ""
    }

    /// Java 详细信息说明，用于 InfoIconWithPopover 展示
    var javaDetailsDescription: String {
        let versionPart = javaVersionInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathPart = effectiveJavaPath.trimmingCharacters(in: .whitespacesAndNewlines)

        return [pathPart, versionPart]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// 获取当前游戏的 Java 版本
    var currentJavaVersion: Int {
        currentGame?.javaVersion ?? 8
    }

    /// 根据当前 Java 版本获取可用的垃圾回收器
    var availableGarbageCollectors: [GarbageCollector] {
        GarbageCollector.allCases.filter { $0.isSupported(by: currentJavaVersion) }
    }

    /// 根据当前选择的垃圾回收器获取可用的优化预设
    /// 最大优化仅在 G1GC 时可用
    var availableOptimizationPresets: [OptimizationPreset] {
        if selectedGarbageCollector == .g1gc {
            return OptimizationPreset.allCases
        }
        return OptimizationPreset.allCases.filter { $0 != .maximum }
    }

    // MARK: - Bind / lifecycle

    func setRepository(_ repository: GameRepository) {
        self.gameRepository = repository
    }

    func onAppearOrGameChanged() {
        loadCurrentSettings()
        loadJavaVersionInfo()
    }

    func onJavaPathChanged() {
        loadJavaVersionInfo()
    }

    // MARK: - UI event handlers

    func didSelectGarbageCollector() {
        guard !isUsingCustomArguments else { return }

        if !selectedGarbageCollector.isSupported(by: currentJavaVersion) {
            selectedGarbageCollector = availableGarbageCollectors.first ?? .g1gc
        }

        if optimizationPreset == .maximum && selectedGarbageCollector != .g1gc {
            optimizationPreset = .balanced
            applyOptimizationPreset(.balanced)
        }

        autoSave()
    }

    func didSelectOptimizationPreset(_ newValue: OptimizationPreset) {
        guard !isUsingCustomArguments else { return }
        applyOptimizationPreset(newValue)
        autoSave()
    }

    func didChangeMemoryRange() {
        autoSave()
    }

    func didChangeCustomJvmArguments() {
        autoSave()
    }

    func didChangeEnvironmentVariables() {
        autoSave()
    }

    func resetToDefaults() {
        isLoadingSettings = true
        defer { isLoadingSettings = false }

        memoryRange = Double(GameSettingsManager.shared.globalXms)...Double(GameSettingsManager.shared.globalXmx)
        selectedGarbageCollector = availableGarbageCollectors.first ?? .g1gc
        optimizationPreset = .balanced
        applyOptimizationPreset(.balanced)
        customJvmArguments = ""
        environmentVariables = ""
        resetJavaPathSafely()
        autoSave()
    }

    func resetJavaPathSafely() {
        guard let game = currentGame else { return }

        Task {
            let defaultPath = await JavaManager.shared.findDefaultJavaPath(for: game.gameVersion)
            await MainActor.run {
                self.javaPath = defaultPath
                self.autoSave()
            }
        }
    }

    func handleJavaPathSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: url.path) else {
                error = GlobalError.fileSystem(
                    chineseMessage: "选择的文件不存在",
                    i18nKey: "error.filesystem.file_not_found",
                    level: .notification
                )
                return
            }

            if JavaManager.shared.canJavaRun(at: url.path) {
                javaPath = url.path
                autoSave()
                Logger.shared.info("Java路径已设置为: \(url.path)")
            } else {
                error = GlobalError.validation(
                    chineseMessage: "选择的文件不是有效的Java可执行文件",
                    i18nKey: "error.validation.invalid_java_executable",
                    level: .popup
                )
            }

        case .failure(let err):
            error = GlobalError.fileSystem(
                chineseMessage: "选择Java路径失败: \(err.localizedDescription)",
                i18nKey: "error.filesystem.java_path_selection_failed",
                level: .notification
            )
        }
    }

    // MARK: - Loading

    private func loadCurrentSettings() {
        guard let game = currentGame else { return }
        isLoadingSettings = true
        defer { isLoadingSettings = false }

        let xms = game.xms == 0 ? GameSettingsManager.shared.globalXms : game.xms
        let xmx = game.xmx == 0 ? GameSettingsManager.shared.globalXmx : game.xmx
        memoryRange = Double(xms)...Double(xmx)
        environmentVariables = game.environmentVariables
        javaPath = game.javaPath

        let jvmArgs = game.jvmArguments.trimmingCharacters(in: .whitespacesAndNewlines)
        if jvmArgs.isEmpty {
            customJvmArguments = ""
            selectedGarbageCollector = availableGarbageCollectors.first ?? .g1gc
            optimizationPreset = .balanced
            applyOptimizationPreset(.balanced)
        } else {
            customJvmArguments = parseExistingJvmArguments(jvmArgs) ? "" : jvmArgs
            if !selectedGarbageCollector.isSupported(by: currentJavaVersion) {
                selectedGarbageCollector = availableGarbageCollectors.first ?? .g1gc
                applyOptimizationPreset(.balanced)
            }
        }
    }

    /// 读取当前生效 Java 路径的 `java --version` 输出
    private func loadJavaVersionInfo() {
        let path = effectiveJavaPath

        guard !path.isEmpty else {
            javaVersionInfo = ""
            return
        }

        Task {
            let info = JavaManager.shared.getJavaVersionInfo(at: path) ?? ""
            await MainActor.run {
                if self.effectiveJavaPath == path {
                    self.javaVersionInfo = info
                }
            }
        }
    }

    // MARK: - JVM args parsing / generation

    private func parseExistingJvmArguments(_ arguments: String) -> Bool {
        let args = arguments.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        let gcMap: [(String, GarbageCollector)] = [
            ("-XX:+UseG1GC", .g1gc),
            ("-XX:+UseZGC", .zgc),
            ("-XX:+UseShenandoahGC", .shenandoah),
            ("-XX:+UseParallelGC", .parallel),
            ("-XX:+UseSerialGC", .serial),
        ]

        guard let (_, gc) = gcMap.first(where: { args.contains($0.0) }) else {
            selectedGarbageCollector = availableGarbageCollectors.first ?? .g1gc
            optimizationPreset = .balanced
            applyOptimizationPreset(.balanced)
            return false
        }

        if gc.isSupported(by: currentJavaVersion) {
            selectedGarbageCollector = gc
        } else {
            Logger.shared.warning("检测到不兼容的垃圾回收器 \(gc.displayName)（需要 Java \(gc.minimumJavaVersion)+，当前 Java \(currentJavaVersion)），自动切换到兼容选项")
            selectedGarbageCollector = availableGarbageCollectors.first ?? .g1gc
            optimizationPreset = .balanced
            applyOptimizationPreset(.balanced)
            return false
        }

        enableOptimizations = args.contains("-XX:+OptimizeStringConcat") ||
            args.contains("-XX:+OmitStackTraceInFastThrow")
        enableMemoryOptimizations = args.contains("-XX:+UseCompressedOops") ||
            args.contains("-XX:+UseCompressedClassPointers") ||
            args.contains("-XX:+UseCompactObjectHeaders")
        enableThreadOptimizations = args.contains("-XX:+OmitStackTraceInFastThrow")

        if selectedGarbageCollector == .g1gc {
            enableAikarFlags = args.contains("-XX:+ParallelRefProcEnabled") &&
                args.contains("-XX:MaxGCPauseMillis=200") &&
                args.contains("-XX:+AlwaysPreTouch")
        } else {
            enableAikarFlags = false
        }

        enableNetworkOptimizations = args.contains("-Djava.net.preferIPv4Stack=true")
        updateOptimizationPreset()

        if optimizationPreset == .maximum && selectedGarbageCollector != .g1gc {
            optimizationPreset = .balanced
            applyOptimizationPreset(.balanced)
        }
        return true
    }

    private func applyOptimizationPreset(_ preset: OptimizationPreset) {
        switch preset {
        case .disabled:
            enableOptimizations = false
            enableAikarFlags = false
            enableMemoryOptimizations = false
            enableThreadOptimizations = false
            enableNetworkOptimizations = false

        case .basic, .balanced:
            enableOptimizations = true
            enableAikarFlags = false
            enableMemoryOptimizations = true
            enableThreadOptimizations = true
            enableNetworkOptimizations = false

        case .maximum:
            enableOptimizations = true
            enableAikarFlags = true
            enableMemoryOptimizations = true
            enableThreadOptimizations = true
            enableNetworkOptimizations = true
        }
    }

    private func updateOptimizationPreset() {
        if !enableOptimizations {
            optimizationPreset = .disabled
        } else if enableAikarFlags && enableNetworkOptimizations {
            optimizationPreset = .maximum
        } else if enableMemoryOptimizations && enableThreadOptimizations {
            optimizationPreset = .balanced
        } else {
            optimizationPreset = .basic
        }
    }

    private func generateJvmArguments() -> String {
        let trimmed = customJvmArguments.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return customJvmArguments
        }

        let gc = selectedGarbageCollector.isSupported(by: currentJavaVersion)
            ? selectedGarbageCollector
            : (availableGarbageCollectors.first ?? .g1gc)

        var arguments: [String] = []
        arguments.append(contentsOf: gc.arguments)

        if gc == .g1gc {
            arguments.append(contentsOf: [
                "-XX:+ParallelRefProcEnabled",
                "-XX:MaxGCPauseMillis=200",
            ])

            if enableAikarFlags {
                arguments.append(contentsOf: [
                    "-XX:+UnlockExperimentalVMOptions",
                    "-XX:+DisableExplicitGC",
                    "-XX:+AlwaysPreTouch",
                    "-XX:G1NewSizePercent=30",
                    "-XX:G1MaxNewSizePercent=40",
                    "-XX:G1HeapRegionSize=8M",
                    "-XX:G1ReservePercent=20",
                    "-XX:G1HeapWastePercent=5",
                    "-XX:G1MixedGCCountTarget=4",
                    "-XX:InitiatingHeapOccupancyPercent=15",
                    "-XX:G1MixedGCLiveThresholdPercent=90",
                    "-XX:G1RSetUpdatingPauseTimePercent=5",
                    "-XX:SurvivorRatio=32",
                    "-XX:MaxTenuringThreshold=1",
                ])
            }
        }

        if enableOptimizations {
            arguments.append(contentsOf: [
                "-XX:+OptimizeStringConcat",
                "-XX:+OmitStackTraceInFastThrow",
            ])
        }

        if enableMemoryOptimizations {
            if currentJavaVersion < 15 {
                arguments.append("-XX:+UseCompressedOops")
            } else if currentJavaVersion < 25 {
                arguments.append(contentsOf: [
                    "-XX:+UseCompressedOops",
                    "-XX:+UseCompressedClassPointers",
                ])
            } else {
                arguments.append(contentsOf: [
                    "-XX:+UseCompressedOops",
                    "-XX:+UseCompressedClassPointers",
                    "-XX:+UseCompactObjectHeaders",
                ])
            }
        }

        if enableNetworkOptimizations {
            arguments.append("-Djava.net.preferIPv4Stack=true")
        }

        return arguments.joined(separator: " ")
    }

    // MARK: - Persistence

    private func autoSave() {
        guard !isLoadingSettings, currentGame != nil else { return }
        saveTask?.cancel()

        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }

            do {
                guard let repository = self.gameRepository else { return }
                guard let game = self.currentGame else { return }

                let xms = Int(self.memoryRange.lowerBound)
                let xmx = Int(self.memoryRange.upperBound)

                guard xms > 0 && xmx > 0 else { return }
                guard xms <= xmx else { return }

                var updatedGame = game
                updatedGame.xms = xms
                updatedGame.xmx = xmx
                updatedGame.jvmArguments = self.generateJvmArguments()
                updatedGame.environmentVariables = self.environmentVariables
                updatedGame.javaPath = self.javaPath

                try await repository.updateGame(updatedGame)
                Logger.shared.debug("自动保存游戏设置: \(game.gameName)")
            } catch {
                let globalError = error as? GlobalError ?? GlobalError.unknown(
                    chineseMessage: "保存设置失败: \(error.localizedDescription)",
                    i18nKey: "error.unknown.settings_save_failed",
                    level: .notification
                )
                Logger.shared.error("自动保存游戏设置失败: \(globalError.chineseMessage)")
                await MainActor.run { self.error = globalError }
            }
        }
    }
}

