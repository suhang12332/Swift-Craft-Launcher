//
//  GameAdvancedSettingsView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/2.
//

import SwiftUI
import UniformTypeIdentifiers

struct GameAdvancedView: View {
    let game: GameVersionInfo
    @EnvironmentObject var gameRepository: GameRepository
    @Environment(\.dismiss)
    private var dismiss

    // 内存设置
    @State private var memoryRange: ClosedRange<Double> =
        Double(
            GameSettingsManager.shared.globalXms
        )...Double(GameSettingsManager.shared.globalXmx)

    // JVM优化设置
    @State private var selectedGarbageCollector: GarbageCollector = .g1gc
    @State private var optimizationPreset: OptimizationPreset = .balanced
    @State private var enableOptimizations: Bool = true
    @State private var enableAikarFlags: Bool = false
    @State private var enableClientOptimizations: Bool = true
    @State private var enableMemoryOptimizations: Bool = true
    @State private var enableThreadOptimizations: Bool = true
    @State private var enableNetworkOptimizations: Bool = false

    // 自定义JVM参数
    @State private var customJvmArguments: String = ""

    // 环境变量设置
    @State private var environmentVariables: String = ""

    // UI状态
    @State private var showSaveAlert = false
    @State private var showResetAlert = false
    @State private var error: GlobalError?

    var body: some View {
        Form {
            // 内存设置
            LabeledContent("settings.game.java.memory".localized()) {
                HStack(spacing: 8) {
                    MiniRangeSlider(
                        range: $memoryRange,
                        bounds:
                            512...Double(
                                GameSettingsManager.shared
                                    .maximumMemoryAllocation
                            )
                    )
                    .frame(width: 200, height: 20)
                    .onChange(of: memoryRange) { _, _ in
                        // 实时更新内存值
                    }
                    Text(
                        "\(Int(memoryRange.lowerBound)) MB - \(Int(memoryRange.upperBound)) MB"
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                }
            }
            .labeledContentStyle(.custom)
            .padding(.bottom, 10)

            // 垃圾回收器设置
            LabeledContent("settings.game.java.garbage_collector".localized()) {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("", selection: $selectedGarbageCollector) {
                        ForEach(GarbageCollector.allCases, id: \.self) { gc in
                            Text(gc.displayName).tag(gc)
                        }
                    }
                    .labelsHidden()
                    .if(ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26) { view in
                        view.fixedSize()
                    }
                    Text(selectedGarbageCollector.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .labeledContentStyle(.custom(alignment: .firstTextBaseline))

            // 性能优化设置
             LabeledContent("settings.game.java.performance_optimization".localized()) {
                 VStack(alignment: .leading) {
                     Picker("", selection: $optimizationPreset) {
                         ForEach(OptimizationPreset.allCases, id: \.self) { preset in
                             Text(preset.displayName).tag(preset)
                         }
                     }
                     .labelsHidden()
                     .if(ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26) { view in
                         view.fixedSize()
                     }
                     .onChange(of: optimizationPreset) { _, newValue in
                         applyOptimizationPreset(newValue)
                     }
                     Text(optimizationPreset.description)
                         .font(.caption)
                         .foregroundColor(.secondary)
                 }
             }
             .labeledContentStyle(.custom(alignment: .firstTextBaseline))
////
            // 自定义JVM参数
            LabeledContent("settings.game.java.custom_parameters".localized()) {
                VStack(alignment: .leading) {
                    TextField(
                        "example: -XX:+UseG1GC",
                        text: $customJvmArguments,
                        axis: .vertical
                    ).focusable(false)
                    .labelsHidden()
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
                    .frame(width: 200)
                    Text(
                        "settings.game.java.custom_parameters.note".localized()
                    )
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            .labeledContentStyle(.custom(alignment: .firstTextBaseline))

            // 环境变量设置
            LabeledContent("settings.game.java.environment_variables".localized()) {
                VStack(alignment: .leading) {
                    TextField(
                        "",
                        text: $environmentVariables,
                        axis: .vertical
                    ).focusable(false)
                    .labelsHidden()
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(2...4)
                    .frame(width: 200)
                    Text(
                        "example: JAVA_OPTS=-Dfile.encoding=UTF-8".localized()
                    )
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            .labeledContentStyle(.custom(alignment: .firstTextBaseline))
            .padding(.bottom, 10)

            // 操作按钮
//            HStack(spacing: 12) {
//                Button("common.reset".localized()) {
//                    showResetAlert = true
//                }
//                .buttonStyle(.bordered)
//                .controlSize(.regular)
//
//                Spacer()
//
//                Button("common.save".localized()) {
//                    saveSettings()
//                }
//                .buttonStyle(.borderedProminent)
//                .controlSize(.regular)
//            }
//            .padding(.top, 10)
        }
        .onAppear {
            loadCurrentSettings()
        }
        .globalErrorHandler()
        .alert(
            "settings.game.save.success".localized(),
            isPresented: $showSaveAlert
        ) {
            Button("common.ok".localized()) {}
        }
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
        // 如果游戏没有自定义内存设置（xms或xmx为0），则显示全局设置
        let xms =
            game.xms == 0 ? GameSettingsManager.shared.globalXms : game.xms
        let xmx =
            game.xmx == 0 ? GameSettingsManager.shared.globalXmx : game.xmx

        memoryRange = Double(xms)...Double(xmx)
        customJvmArguments = game.jvmArguments
        environmentVariables = game.environmentVariables

        // 解析现有的JVM参数来设置UI状态
        parseExistingJvmArguments(game.jvmArguments)
    }

    private func parseExistingJvmArguments(_ arguments: String) {
        let args = arguments.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // 检测垃圾回收器
        if args.contains("-XX:+UseG1GC") {
            selectedGarbageCollector = .g1gc
        } else if args.contains("-XX:+UseZGC") {
            selectedGarbageCollector = .zgc
        } else if args.contains("-XX:+UseShenandoahGC") {
            selectedGarbageCollector = .shenandoah
        } else if args.contains("-XX:+UseParallelGC") {
            selectedGarbageCollector = .parallel
        } else if args.contains("-XX:+UseSerialGC") {
            selectedGarbageCollector = .serial
        }

        // 检测优化设置
        enableOptimizations = !args.contains("-XX:-OptimizeStringConcat")
        enableAikarFlags =
            args.contains("-XX:+UseG1GC")
            && args.contains("-XX:+ParallelRefProcEnabled")
        enableClientOptimizations = args.contains("-XX:+UseCompressedOops")
        enableMemoryOptimizations = args.contains(
            "-XX:+UseCompressedClassPointers"
        )
        enableThreadOptimizations = args.contains("-XX:+UseThreadPriorities")
        enableNetworkOptimizations = args.contains(
            "-Djava.net.preferIPv4Stack=true"
        )
        
        // 根据解析的设置更新优化预设
        updateOptimizationPreset()
    }
    
    private func applyOptimizationPreset(_ preset: OptimizationPreset) {
        switch preset {
        case .none:
            enableOptimizations = false
            enableAikarFlags = false
            enableClientOptimizations = false
            enableMemoryOptimizations = false
            enableThreadOptimizations = false
            enableNetworkOptimizations = false
        case .basic:
            enableOptimizations = true
            enableAikarFlags = false
            enableClientOptimizations = true
            enableMemoryOptimizations = true
            enableThreadOptimizations = true
            enableNetworkOptimizations = false
        case .balanced:
            enableOptimizations = true
            enableAikarFlags = false
            enableClientOptimizations = true
            enableMemoryOptimizations = true
            enableThreadOptimizations = true
            enableNetworkOptimizations = false
        case .maximum:
            enableOptimizations = true
            enableAikarFlags = true
            enableClientOptimizations = true
            enableMemoryOptimizations = true
            enableThreadOptimizations = true
            enableNetworkOptimizations = true
        }
    }
    
    private func updateOptimizationPreset() {
        // 根据当前设置自动检测预设
        if !enableOptimizations {
            optimizationPreset = .none
        } else if enableAikarFlags && enableNetworkOptimizations {
            optimizationPreset = .maximum
        } else if enableClientOptimizations && enableMemoryOptimizations && enableThreadOptimizations {
            optimizationPreset = .balanced
        } else {
            optimizationPreset = .basic
        }
    }

    private func generateJvmArguments() -> String {
        // 如果用户输入了自定义参数，优先使用自定义参数
        if !customJvmArguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customJvmArguments
        }

        var arguments: [String] = []

        // 垃圾回收器参数
        arguments.append(contentsOf: selectedGarbageCollector.arguments)

        // 基础优化
        if enableOptimizations {
            arguments.append(contentsOf: [
                "-XX:+OptimizeStringConcat",
                "-XX:+UseCompressedOops",
                "-XX:+UseCompressedClassPointers",
                "-XX:+UseThreadPriorities",
            ])
        }

        // Aikar优化参数
        if enableAikarFlags {
            let aikarFlags1 = [
                "-XX:+ParallelRefProcEnabled",
                "-XX:MaxGCPauseMillis=200",
                "-XX:+UnlockExperimentalVMOptions",
                "-XX:+DisableExplicitGC",
                "-XX:+AlwaysPreTouch",
            ]
            let aikarFlags2 = [
                "-XX:G1NewSizePercent=30",
                "-XX:G1MaxNewSizePercent=40",
                "-XX:G1HeapRegionSize=8M",
                "-XX:G1ReservePercent=20",
                "-XX:G1HeapWastePercent=5",
            ]
            let aikarFlags3 = [
                "-XX:G1MixedGCCountTarget=4",
                "-XX:InitiatingHeapOccupancyPercent=15",
                "-XX:G1MixedGCLiveThresholdPercent=90",
                "-XX:G1RSetUpdatingPauseTimePercent=5",
                "-XX:SurvivorRatio=32",
            ]
            let aikarFlags4 = [
                "-XX:+PerfDisableSharedMem",
                "-XX:MaxTenuringThreshold=1",
            ]
            arguments.append(contentsOf: aikarFlags1)
            arguments.append(contentsOf: aikarFlags2)
            arguments.append(contentsOf: aikarFlags3)
            arguments.append(contentsOf: aikarFlags4)
        }

        // 客户端优化
        if enableClientOptimizations {
            arguments.append(contentsOf: [
                "-XX:+UseCompressedOops",
                "-XX:+UseCompressedClassPointers",
                "-XX:+UseThreadPriorities",
                "-XX:+OmitStackTraceInFastThrow",
            ])
        }

        // 内存优化
        if enableMemoryOptimizations {
            arguments.append(contentsOf: [
                "-XX:+UseCompressedClassPointers",
                "-XX:+UseCompressedOops",
                "-XX:+AlwaysPreTouch",
            ])
        }

        // 线程优化
        if enableThreadOptimizations {
            arguments.append(contentsOf: [
                "-XX:+UseThreadPriorities",
                "-XX:+OmitStackTraceInFastThrow",
            ])
        }

        // 网络优化
        if enableNetworkOptimizations {
            arguments.append(contentsOf: [
                "-Djava.net.preferIPv4Stack=true",
                "-Djava.net.preferIPv4Addresses=true",
            ])
        }

        return arguments.joined(separator: " ")
    }

    private func saveSettings() {
        Task {
            do {
                // 验证设置
                let xms = Int(memoryRange.lowerBound)
                let xmx = Int(memoryRange.upperBound)

                guard xms > 0 && xmx > 0 else {
                    throw GlobalError.validation(
                        chineseMessage: "内存设置无效",
                        i18nKey: "error.validation.invalid_memory_settings",
                        level: .notification
                    )
                }

                guard xms <= xmx else {
                    throw GlobalError.validation(
                        chineseMessage: "XMS不能大于XMX",
                        i18nKey: "error.validation.xms_greater_than_xmx",
                        level: .notification
                    )
                }

                // 生成JVM参数
                let jvmArgs = generateJvmArguments()

                // 更新游戏设置
                var updatedGame = game
                updatedGame.xms = xms
                updatedGame.xmx = xmx
                updatedGame.jvmArguments = jvmArgs
                updatedGame.environmentVariables = environmentVariables

                // 保存到游戏仓库
                try await gameRepository.updateGame(updatedGame)

                await MainActor.run {
                    showSaveAlert = true
                }

                Logger.shared.info("成功保存游戏设置: \(game.gameName)")
            } catch {
                let globalError: GlobalError
                if let gameError = error as? GlobalError {
                    globalError = gameError
                } else {
                    globalError = GlobalError.unknown(
                        chineseMessage: "保存设置失败: \(error.localizedDescription)",
                        i18nKey: "error.unknown.settings_save_failed",
                        level: .notification
                    )
                }

                Logger.shared.error("保存游戏设置失败: \(globalError.chineseMessage)")
                await MainActor.run {
                    self.error = globalError
                }
            }
        }
    }

    private func resetToDefaults() {
        // 重置为全局默认设置
        memoryRange =
            Double(
                GameSettingsManager.shared.globalXms
            )...Double(GameSettingsManager.shared.globalXmx)
        selectedGarbageCollector = .g1gc
        optimizationPreset = .balanced
        enableOptimizations = true
        enableAikarFlags = false
        enableClientOptimizations = true
        enableMemoryOptimizations = true
        enableThreadOptimizations = true
        enableNetworkOptimizations = false
        customJvmArguments = ""
        environmentVariables = ""
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
    case none = "none"
    case basic = "basic"
    case balanced = "balanced"
    case maximum = "maximum"
    
    var displayName: String {
        switch self {
        case .none: return "settings.game.java.optimization.none".localized()
        case .basic: return "settings.game.java.optimization.basic".localized()
        case .balanced: return "settings.game.java.optimization.balanced".localized()
        case .maximum: return "settings.game.java.optimization.maximum".localized()
        }
    }
    
    var description: String {
        switch self {
        case .none: return "settings.game.java.optimization.none.desc".localized()
        case .basic: return "settings.game.java.optimization.basic.desc".localized()
        case .balanced: return "settings.game.java.optimization.balanced.desc".localized()
        case .maximum: return "settings.game.java.optimization.maximum.desc".localized()
        }
    }
}

