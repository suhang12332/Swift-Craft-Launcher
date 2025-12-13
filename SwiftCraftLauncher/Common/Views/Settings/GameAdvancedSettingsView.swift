//
//  GameAdvancedSettingsView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/2.
//

import SwiftUI

struct GameAdvancedSettingsView: View {
    @EnvironmentObject var gameRepository: GameRepository
    @ObservedObject private var selectedGameManager = SelectedGameManager.shared

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
    @State private var showResetAlert = false
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

            LabeledContent("settings.game.java.garbage_collector".localized()) {
                HStack {
                    Picker("", selection: $selectedGarbageCollector) {
                        ForEach(GarbageCollector.allCases, id: \.self) { gc in
                            Text(gc.displayName).tag(gc)
                        }
                    }
                    .labelsHidden()
                    .if(ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26) { $0.fixedSize() }
                    .disabled(isUsingCustomArguments)  // 使用自定义参数时禁用
                    .onChange(of: selectedGarbageCollector) { _, _ in
                        if !isUsingCustomArguments {
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
                    .if(ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26) { $0.fixedSize() }
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
                    .frame(width: 200, height: 20)
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
            isPresented: .constant(error != nil)
        ) {
            Button("common.close".localized()) {
                error = nil
            }
        } message: {
            if let error = error {
                Text(error.chineseMessage)
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

        let jvmArgs = game.jvmArguments.trimmingCharacters(in: .whitespacesAndNewlines)
        if jvmArgs.isEmpty {
            customJvmArguments = ""
            selectedGarbageCollector = .g1gc
            optimizationPreset = .balanced
            applyOptimizationPreset(.balanced)
        } else {
            customJvmArguments = parseExistingJvmArguments(jvmArgs) ? "" : jvmArgs
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
            selectedGarbageCollector = .g1gc
            optimizationPreset = .balanced
            applyOptimizationPreset(.balanced)
            return false
        }

        selectedGarbageCollector = gc
        // 解析优化选项
        enableOptimizations = args.contains("-XX:+OptimizeStringConcat") ||
                             args.contains("-XX:+OmitStackTraceInFastThrow")
        enableMemoryOptimizations = args.contains("-XX:+UseCompressedOops") ||
                                   args.contains("-XX:+UseCompressedClassPointers")
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

        var arguments: [String] = []
        arguments.append(contentsOf: selectedGarbageCollector.arguments)

        if selectedGarbageCollector == .g1gc {
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
            arguments.append("-XX:+UseCompressedOops")
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
        selectedGarbageCollector = .g1gc
        optimizationPreset = .balanced
        applyOptimizationPreset(.balanced)
        customJvmArguments = ""
        environmentVariables = ""
        autoSave()
    }
}

// MARK: - Garbage Collector Enum

enum GarbageCollector: String, CaseIterable {
    case g1gc = "g1gc"
    case zgc = "zgc"
    case shenandoah = "shenandoah"
    case parallel = "parallel"
    case serial = "serial"

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
