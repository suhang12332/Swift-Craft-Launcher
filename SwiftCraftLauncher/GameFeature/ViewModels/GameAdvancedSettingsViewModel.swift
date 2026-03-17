import Foundation
import UniformTypeIdentifiers

@MainActor
final class GameAdvancedSettingsViewModel: ObservableObject {

    // MARK: - Dependencies

    let selectedGameManager: SelectedGameManager
    var gameRepository: GameRepository?

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

    var enableOptimizations: Bool = true
    var enableAikarFlags: Bool = false
    var enableMemoryOptimizations: Bool = true
    var enableThreadOptimizations: Bool = true
    var enableNetworkOptimizations: Bool = false

    var saveTask: Task<Void, Never>?

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
}
