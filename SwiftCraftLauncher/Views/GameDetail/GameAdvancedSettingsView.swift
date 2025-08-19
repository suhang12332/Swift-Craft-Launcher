//
//  GameAdvancedSettingsView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/2.
//

import SwiftUI
import UniformTypeIdentifiers

struct GameAdvancedSettingsView: View {
    let game: GameVersionInfo
    @EnvironmentObject var gameRepository: GameRepository
    @Environment(\.dismiss) private var dismiss
    
    
    // Java和内存设置
    @State private var memoryRange: ClosedRange<Double> = Double(GameSettingsManager.shared.globalXms)...Double(GameSettingsManager.shared.globalXmx)
    @State private var jvmArguments: String = ""
    @State private var environmentVariables: String = ""
    
    // UI状态
    @State private var showSaveAlert = false
    @State private var showResetAlert = false
    @State private var error: GlobalError?
    

    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                
                // 内存设置
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("settings.game.java.memory".localized())
                            .font(.headline)
                            
                        Spacer()
                        Text("\(Int(memoryRange.lowerBound)) MB - \(Int(memoryRange.upperBound)) MB")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        MiniRangeSlider(range: $memoryRange, bounds: 512...Double(GameSettingsManager.shared.maximumMemoryAllocation))
                            .frame(height: 20)
                            .onChange(of: memoryRange) { old, newValue in
                                // 实时更新内存值
                            }

                    }
                }

                
                // JVM参数设置
                VStack(alignment: .leading, spacing: 12) {
                    Text("settings.game.java.jvm_args".localized())
                        .font(.headline)
                        
                    
                    TextField("例如: -XX:+UseG1GC", text: $jvmArguments, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(2...4)
                }

                
                // 环境变量设置
                VStack(alignment: .leading, spacing: 12) {
                    Text("settings.game.java.env_vars".localized())
                        .font(.headline)
                        
                    
                    TextField("例如: JAVA_OPTS=-Dfile.encoding=UTF-8", text: $environmentVariables, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(2...4)
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

        }
        .onAppear {
            loadCurrentSettings()
        }

        .alert("settings.game.save.success".localized(), isPresented: $showSaveAlert) {
            Button("common.ok".localized()) { }
        }
        .alert("settings.game.reset.confirm".localized(), isPresented: $showResetAlert) {
            Button("common.reset".localized(), role: .destructive) {
                resetToDefaults()
            }
            Button("common.cancel".localized(), role: .cancel) { }
        }
        .alert("error.notification.validation.title".localized(), isPresented: .constant(error != nil)) {
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
        let xms = game.xms == 0 ? GameSettingsManager.shared.globalXms : game.xms
        let xmx = game.xmx == 0 ? GameSettingsManager.shared.globalXmx : game.xmx
        
        memoryRange = Double(xms)...Double(xmx)
        jvmArguments = game.jvmArguments
        environmentVariables = game.environmentVariables
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
                
                // 更新游戏设置
                var updatedGame = game
                updatedGame.xms = xms
                updatedGame.xmx = xmx
//                updatedGame.jvmArguments = jvmArguments
//                updatedGame.windowWidth = windowWidth
//                updatedGame.windowHeight = windowHeight
//                updatedGame.isFullscreen = isFullscreen
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
        memoryRange = Double(GameSettingsManager.shared.globalXms)...Double(GameSettingsManager.shared.globalXmx)
        jvmArguments = ""
        environmentVariables = ""
    }
}

#Preview {
    GameAdvancedSettingsView(game: GameVersionInfo(
        gameName: "Test Game",
        gameIcon: "",
        gameVersion: "1.20.1",
        assetIndex: "1.20.1",
        modLoader: "Fabric",
        isUserAdded: true
    ))
    .environmentObject(GameRepository())
}
