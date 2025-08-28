//
//  GameAdvancedSettingsView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/2.
//

import SwiftUI
import UniformTypeIdentifiers

struct GameAdvancedSettingsView: View { // swiftlint:disable:this type_body_length
    let game: GameVersionInfo
    @EnvironmentObject var gameRepository: GameRepository
    @Environment(\.dismiss) private var dismiss

    // 内存设置
    @State private var memoryRange: ClosedRange<Double> =
        Double(
            GameSettingsManager.shared.globalXms
        )...Double(GameSettingsManager.shared.globalXmx)

    // JVM优化设置
    @State private var selectedGarbageCollector: GarbageCollector = .g1gc
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
        VStack(alignment: .leading, spacing: 20) {

            // 内存设置
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "memorychip")
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .medium))
                    Text("settings.game.java.memory".localized())
                        .font(.headline)

                    Spacer()
                    Text("暂不可用").foregroundColor(.secondary).font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 12) {
                    MiniRangeSlider(
                        range: $memoryRange,
                        bounds:
                            512...Double(
                                GameSettingsManager.shared
                                    .maximumMemoryAllocation
                            )
                    )
                    .frame(height: 20)
                    .onChange(of: memoryRange) { old, newValue in
                        // 实时更新内存值
                    }

                    HStack {
                        Text(
                            "settings.game.java.memory.recommendation"
                                .localized()
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                        Spacer()
                        Text(
                            "\(Int(memoryRange.lowerBound)) MB - \(Int(memoryRange.upperBound)) MB"
                        )
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    }
                }
            }

            // 垃圾回收器设置
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.green)
                        .font(.system(size: 16, weight: .medium))
                    Text("settings.game.java.garbage_collector".localized())
                        .font(.headline)
                    Spacer()
                    Text("暂不可用").foregroundColor(.secondary).font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 12) {

                    ForEach(GarbageCollector.allCases, id: \.self) { gc in
                        HStack {
                            Button {
                                selectedGarbageCollector = gc
                            } label: {
                                HStack {
                                    Image(
                                        systemName: selectedGarbageCollector
                                            == gc
                                            ? "checkmark.circle.fill" : "circle"
                                    )
                                    .foregroundColor(
                                        selectedGarbageCollector == gc
                                            ? .blue : .gray
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(gc.displayName)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Text(gc.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // 性能优化设置
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "speedometer")
                        .foregroundColor(.orange)
                        .font(.system(size: 16, weight: .medium))
                    Text(
                        "settings.game.java.performance_optimization"
                            .localized()
                    )
                    .font(.headline)
                    Spacer()
                    Text("暂不可用").foregroundColor(.secondary).font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 16) {
                    // 基础优化
                    VStack(alignment: .leading, spacing: 8) {

                        Toggle(
                            "settings.game.java.enable_jvm_optimization"
                                .localized(),
                            isOn: $enableOptimizations
                        )
                        .toggleStyle(SwitchToggleStyle())
                        .controlSize(.mini)
                        .font(.subheadline)

                        Toggle(
                            "settings.game.java.enable_aikar_flags".localized(),
                            isOn: $enableAikarFlags
                        )
                        .toggleStyle(SwitchToggleStyle())
                        .disabled(!enableOptimizations)
                        .controlSize(.mini)
                        .font(
                            .subheadline
                        )
                        Toggle(
                            "settings.game.java.enable_client_optimization"
                                .localized(),
                            isOn: $enableClientOptimizations
                        )
                        .toggleStyle(SwitchToggleStyle())
                        .controlSize(.mini)
                        .font(.subheadline)
                        .disabled(!enableOptimizations)

                        Toggle(
                            "settings.game.java.enable_memory_optimization"
                                .localized(),
                            isOn: $enableMemoryOptimizations
                        )
                        .toggleStyle(SwitchToggleStyle())
                        .controlSize(.mini)
                        .font(.subheadline)
                        .disabled(!enableOptimizations)

                        Toggle(
                            "settings.game.java.enable_thread_optimization"
                                .localized(),
                            isOn: $enableThreadOptimizations
                        )
                        .toggleStyle(SwitchToggleStyle())
                        .controlSize(.mini)
                        .font(.subheadline)
                        .disabled(!enableOptimizations)
                    }
                }
            }

            // 自定义JVM参数
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.purple)
                        .font(.system(size: 16, weight: .medium))
                    Text("settings.game.java.custom_parameters".localized())
                        .font(.headline)
                    Spacer()
                    Text("暂不可用").foregroundColor(.secondary).font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(
                        "settings.game.java.jvm_args".localized() + " (每行一个参数):"
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    TextField(
                        "example: -XX:+UseG1GC",
                        text: $customJvmArguments,
                        axis: .vertical
                    )
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)

                    Text(
                        "settings.game.java.custom_parameters.note".localized()
                    )
                    .font(.caption)
                    .foregroundColor(.orange)
                }
            }

            // 环境变量设置
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "gearshape.2")
                        .foregroundColor(.teal)
                        .font(.system(size: 16, weight: .medium))
                    Text("settings.game.java.environment_variables".localized())
                        .font(.headline)
                    Spacer()
                    Text("暂不可用").foregroundColor(.secondary).font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 12) {
                    TextField(
                        "example: JAVA_OPTS=-Dfile.encoding=UTF-8",
                        text: $environmentVariables,
                        axis: .vertical
                    )
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(2...4)
                }
            }

            // 操作按钮
            HStack(spacing: 12) {
                Button("common.reset".localized()) {
                    showResetAlert = true
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                Button("common.save".localized()) {
                    saveSettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }

        .onAppear {
            loadCurrentSettings()
        }
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
    }

    private func generateJvmArguments() -> String {
        // 如果用户输入了自定义参数，优先使用自定义参数
        if !customJvmArguments.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        {
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
            arguments.append(contentsOf: [
                "-XX:+ParallelRefProcEnabled",
                "-XX:MaxGCPauseMillis=200",
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
                "-XX:+PerfDisableSharedMem",
                "-XX:MaxTenuringThreshold=1",
            ])
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
