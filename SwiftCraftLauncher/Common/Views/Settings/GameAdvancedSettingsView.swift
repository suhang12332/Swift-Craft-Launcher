//
//  GameAdvancedSettingsView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/2.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct GameAdvancedSettingsView: View {
    @EnvironmentObject var gameRepository: GameRepository
    @StateObject private var selectedGameManager = SelectedGameManager.shared

    @State private var memoryRange: ClosedRange<Double> = Double(GameSettingsManager.shared.globalXms)...Double(GameSettingsManager.shared.globalXmx)
    @State private var selectedGarbageCollector: GarbageCollector = .g1gc
    @State private var optimizationPreset: OptimizationPreset = .balanced
    @State private var enableOptimizations: Bool = true
    @State private var enableAikarFlags: Bool = false
    @State private var enableMemoryOptimizations: Bool = true
    @State private var enableThreadOptimizations: Bool = true
    @State private var enableNetworkOptimizations: Bool = false
    @State private var customJvmArguments: String = ""
    @State private var environmentVariables: String = ""
    @State private var javaPath: String = ""
    @State private var showResetAlert = false
    @State private var showJavaPathPicker = false
    @State private var error: GlobalError?
    @State private var isLoadingSettings = false
    @State private var saveTask: Task<Void, Never>?

    private var currentGame: GameVersionInfo? {
        guard let gameId = selectedGameManager.selectedGameId else { return nil }
        return gameRepository.getGame(by: gameId)
    }

    /// 是否使用自定义JVM参数（与垃圾回收器和性能优化互斥）
    private var isUsingCustomArguments: Bool {
        !customJvmArguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 获取当前游戏的 Java 版本
    private var currentJavaVersion: Int {
        currentGame?.javaVersion ?? 8
    }

    /// 根据当前 Java 版本获取可用的垃圾回收器
    private var availableGarbageCollectors: [GarbageCollector] {
        GarbageCollector.allCases.filter { gc in
            gc.isSupported(by: currentJavaVersion)
        }
    }

    /// 根据当前选择的垃圾回收器获取可用的优化预设
    /// 最大优化仅在 G1GC 时可用
    private var availableOptimizationPresets: [OptimizationPreset] {
        if selectedGarbageCollector == .g1gc {
            // G1GC 支持所有优化预设，包括最大优化
            return OptimizationPreset.allCases
        } else {
            // 非 G1GC 不支持最大优化（因为 Aikar Flags 仅适用于 G1GC）
            return OptimizationPreset.allCases.filter { $0 != .maximum }
        }
    }

    var body: some View {
        Form {
            LabeledContent("settings.game.java.path".localized()) {
                DirectorySettingRow(
                    title: "settings.game.java.path".localized(),
                    path: javaPath.isEmpty ? (currentGame?.javaPath ?? "") : javaPath,
                    description: "settings.game.java.path.description".localized(),
                    onChoose: { showJavaPathPicker = true },
                    onReset: {
                        resetJavaPathSafely()
                    }
                ).fixedSize()
                    .fileImporter(
                        isPresented: $showJavaPathPicker,
                        allowedContentTypes: [.item],
                        allowsMultipleSelection: false
                    ) { result in
                        handleJavaPathSelection(result)
                    }
            }.labeledContentStyle(.custom(alignment: .firstTextBaseline))

            LabeledContent("settings.game.java.garbage_collector".localized()) {
                HStack {
                    Picker("", selection: $selectedGarbageCollector) {
                        ForEach(availableGarbageCollectors, id: \.self) { gc in
                            Text(gc.displayName).tag(gc)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .disabled(isUsingCustomArguments)  // 使用自定义参数时禁用
                    .onChange(of: selectedGarbageCollector) { _, _ in
                        if !isUsingCustomArguments {
                            // 如果选择的垃圾回收器不支持当前 Java 版本，自动切换到支持的选项
                            if !selectedGarbageCollector.isSupported(by: currentJavaVersion) {
                                selectedGarbageCollector = availableGarbageCollectors.first ?? .g1gc
                            }
                            autoSave()
                        }
                    }
                    InfoIconWithPopover(text: selectedGarbageCollector.description)
                }
            }
            .labeledContentStyle(.custom(alignment: .firstTextBaseline))
            .opacity(isUsingCustomArguments ? 0.5 : 1.0)  // 禁用时降低透明度

            LabeledContent("settings.game.java.performance_optimization".localized()) {
                HStack {
                    Picker("", selection: $optimizationPreset) {
                        // 最大优化仅在 G1GC 时可用
                        ForEach(availableOptimizationPresets, id: \.self) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .disabled(isUsingCustomArguments)  // 使用自定义参数时禁用
                    .onChange(of: optimizationPreset) { _, newValue in
                        if !isUsingCustomArguments {
                            applyOptimizationPreset(newValue)
                            autoSave()
                        }
                    }
                    .onChange(of: selectedGarbageCollector) { _, _ in
                        // 当垃圾回收器改变时，如果当前是最大优化但不是 G1GC，则切换到平衡优化
                        if optimizationPreset == .maximum && selectedGarbageCollector != .g1gc {
                            optimizationPreset = .balanced
                            applyOptimizationPreset(.balanced)
                            autoSave()
                        }
                    }
                    InfoIconWithPopover(text: optimizationPreset.description)
                }
            }
            .labeledContentStyle(.custom(alignment: .firstTextBaseline))
            .opacity(isUsingCustomArguments ? 0.5 : 1.0)  // 禁用时降低透明度

            LabeledContent("settings.game.java.memory".localized()) {
                HStack {
                    MiniRangeSlider(
                        range: $memoryRange,
                        bounds: 512...Double(GameSettingsManager.shared.maximumMemoryAllocation)
                    )
                    .frame(width: 200)
                    .controlSize(.mini)
                    .onChange(of: memoryRange) { _, _ in autoSave() }
                    Text("\(Int(memoryRange.lowerBound)) MB-\(Int(memoryRange.upperBound)) MB")
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .labeledContentStyle(.custom)

            LabeledContent("settings.game.java.custom_parameters".localized()) {
                HStack {
                    TextField("", text: $customJvmArguments)
                        .focusable(false)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .frame(width: 200)
                        .onChange(of: customJvmArguments) { _, _ in autoSave() }
                    InfoIconWithPopover(text: "settings.game.java.custom_parameters.note".localized())
                }
            }
            .labeledContentStyle(.custom(alignment: .firstTextBaseline))

            LabeledContent {
                HStack {
                    TextField("", text: $environmentVariables, axis: .vertical)
                        .focusable(false)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .frame(width: 200)
                        .onChange(of: environmentVariables) { _, _ in autoSave() }
                    InfoIconWithPopover(text: "example: JAVA_OPTS=-Dfile.encoding=UTF-8".localized())
                }
            } label: {
                Text("settings.game.java.environment_variables".localized())
            }
            .labeledContentStyle(.custom)
        }
        .onAppear { loadCurrentSettings() }
        .onChange(of: selectedGameManager.selectedGameId) { _, _ in loadCurrentSettings() }
        .globalErrorHandler()
        .alert(
            "settings.game.reset.confirm".localized(),
            isPresented: $showResetAlert
        ) {
            Button("common.reset".localized(), role: .destructive) {
                resetToDefaults()
            }
            Button("common.cancel".localized(), role: .cancel) {}
        }
        .alert(
            "error.notification.validation.title".localized(),
            isPresented: .constant(error != nil && error?.level == .popup)
        ) {
            Button("common.close".localized()) {
                error = nil
            }
        } message: {
            if let error = error {
                Text(error.localizedDescription)
            }
        }
    }

    // MARK: - Private Methods

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
            // 根据 Java 版本选择默认垃圾回收器
            selectedGarbageCollector = availableGarbageCollectors.first ?? .g1gc
            optimizationPreset = .balanced
            applyOptimizationPreset(.balanced)
        } else {
            customJvmArguments = parseExistingJvmArguments(jvmArgs) ? "" : jvmArgs
            // 如果解析出的垃圾回收器不支持当前 Java 版本，自动切换到支持的选项
            if !selectedGarbageCollector.isSupported(by: currentJavaVersion) {
                selectedGarbageCollector = availableGarbageCollectors.first ?? .g1gc
                applyOptimizationPreset(.balanced)
            }
        }
    }

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

        // 验证垃圾回收器是否支持当前 Java 版本
        if gc.isSupported(by: currentJavaVersion) {
            selectedGarbageCollector = gc
        } else {
            // 如果不支持，使用默认支持的垃圾回收器
            Logger.shared.warning("检测到不兼容的垃圾回收器 \(gc.displayName)（需要 Java \(gc.minimumJavaVersion)+，当前 Java \(currentJavaVersion)），自动切换到兼容选项")
            selectedGarbageCollector = availableGarbageCollectors.first ?? .g1gc
            optimizationPreset = .balanced
            applyOptimizationPreset(.balanced)
            return false
        }
        // 解析优化选项
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

        // 确保最大优化仅在 G1GC 时可用
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

        // 确保选择的垃圾回收器支持当前 Java 版本
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

        // 内存优化参数
        // Java 8-14: UseCompressedOops 和 UseCompressedClassPointers 绑定
        // Java 15-24: 显式指定 Oops + ClassPointers
        // Java 25+: 再额外启用 CompactObjectHeaders
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

    private func autoSave() {
        // 如果正在加载设置，不触发自动保存
        guard !isLoadingSettings, currentGame != nil else { return }

        // 取消之前的保存任务
        saveTask?.cancel()

        // 使用防抖机制，延迟 0.5 秒后保存
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒

            guard !Task.isCancelled else { return }

            do {
                guard let game = currentGame else { return }
                let xms = Int(memoryRange.lowerBound)
                let xmx = Int(memoryRange.upperBound)

                guard xms > 0 && xmx > 0 else { return }
                guard xms <= xmx else { return }

                var updatedGame = game
                updatedGame.xms = xms
                updatedGame.xmx = xmx
                updatedGame.jvmArguments = generateJvmArguments()
                updatedGame.environmentVariables = environmentVariables
                updatedGame.javaPath = javaPath

                try await gameRepository.updateGame(updatedGame)
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

    private func resetToDefaults() {
        isLoadingSettings = true
        defer { isLoadingSettings = false }

        memoryRange = Double(GameSettingsManager.shared.globalXms)...Double(GameSettingsManager.shared.globalXmx)
        // 根据 Java 版本选择默认垃圾回收器
        selectedGarbageCollector = availableGarbageCollectors.first ?? .g1gc
        optimizationPreset = .balanced
        applyOptimizationPreset(.balanced)
        customJvmArguments = ""
        environmentVariables = ""
        resetJavaPathSafely()
        autoSave()
    }

    /// 安全地重置Java路径
    private func resetJavaPathSafely() {
        guard let game = currentGame else { return }

        Task {
            let defaultPath = await JavaManager.shared.findDefaultJavaPath(for: game.gameVersion)
            await MainActor.run {
                javaPath = defaultPath
                autoSave()
            }
        }
    }

    /// 处理Java路径选择结果
    private func handleJavaPathSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                // 验证文件是否存在且可执行
                let fileManager = FileManager.default
                guard fileManager.fileExists(atPath: url.path) else {
                    error = GlobalError.fileSystem(
                        chineseMessage: "选择的文件不存在",
                        i18nKey: "error.filesystem.file_not_found",
                        level: .notification
                    )
                    return
                }

                // 验证是否为可执行文件（通过JavaManager验证）
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
            }
        case .failure(let error):
            let globalError = GlobalError.fileSystem(
                chineseMessage: "选择Java路径失败: \(error.localizedDescription)",
                i18nKey: "error.filesystem.java_path_selection_failed",
                level: .notification
            )
            self.error = globalError
        }
    }
}

// MARK: - Garbage Collector Enum

enum GarbageCollector: String, CaseIterable {
    case g1gc = "g1gc"
    case zgc = "zgc"
    case shenandoah = "shenandoah"
    case parallel = "parallel"
    case serial = "serial"

    /// 垃圾回收器所需的最低 Java 版本
    var minimumJavaVersion: Int {
        switch self {
        case .g1gc: return 7      // Java 7+ (G1GC 在 Java 7u4+ 可用)
        case .parallel: return 1   // Java 1.0+ (所有版本都支持)
        case .serial: return 1     // Java 1.0+ (所有版本都支持)
        case .zgc: return 11      // Java 11+ (ZGC 在 Java 11 引入)
        case .shenandoah: return 12 // Java 12+ (Shenandoah 在 Java 12 引入)
        }
    }

    /// 检查垃圾回收器是否支持指定的 Java 版本
    /// - Parameter javaVersion: Java 主版本号（如 8, 11, 17）
    /// - Returns: 是否支持
    func isSupported(by javaVersion: Int) -> Bool {
        return javaVersion >= minimumJavaVersion
    }

    var displayName: String {
        switch self {
        case .g1gc: return "settings.game.java.gc.g1gc".localized()
        case .zgc: return "settings.game.java.gc.zgc".localized()
        case .shenandoah: return "settings.game.java.gc.shenandoah".localized()
        case .parallel: return "settings.game.java.gc.parallel".localized()
        case .serial: return "settings.game.java.gc.serial".localized()
        }
    }

    var description: String {
        switch self {
        case .g1gc: return "settings.game.java.gc.g1gc.desc".localized()
        case .zgc: return "settings.game.java.gc.zgc.desc".localized()
        case .shenandoah:
            return "settings.game.java.gc.shenandoah.desc".localized()
        case .parallel: return "settings.game.java.gc.parallel.desc".localized()
        case .serial: return "settings.game.java.gc.serial.desc".localized()
        }
    }

    var arguments: [String] {
        switch self {
        case .g1gc: return ["-XX:+UseG1GC"]
        case .zgc: return ["-XX:+UseZGC"]
        case .shenandoah: return ["-XX:+UseShenandoahGC"]
        case .parallel: return ["-XX:+UseParallelGC"]
        case .serial: return ["-XX:+UseSerialGC"]
        }
    }
}

// MARK: - Optimization Preset Enum

enum OptimizationPreset: String, CaseIterable {
    case disabled = "disabled"
    case basic = "basic"
    case balanced = "balanced"
    case maximum = "maximum"

    var displayName: String {
        switch self {
        case .disabled: return "settings.game.java.optimization.none".localized()
        case .basic: return "settings.game.java.optimization.basic".localized()
        case .balanced:
            return "settings.game.java.optimization.balanced".localized()
        case .maximum:
            return "settings.game.java.optimization.maximum".localized()
        }
    }

    var description: String {
        switch self {
        case .disabled:
            return "settings.game.java.optimization.none.desc".localized()
        case .basic:
            return "settings.game.java.optimization.basic.desc".localized()
        case .balanced:
            return "settings.game.java.optimization.balanced.desc".localized()
        case .maximum:
            return "settings.game.java.optimization.maximum.desc".localized()
        }
    }
}
