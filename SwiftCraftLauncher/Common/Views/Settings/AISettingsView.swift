//
//  AISettingsView.swift
//  SwiftCraftLauncher
//
//  Created by AI Assistant
//

import SwiftUI

public struct AISettingsView: View {
    @ObservedObject private var aiSettings = AISettingsManager.shared
    @State private var showApiKey = false
    public var body: some View {
        Form {
            LabeledContent("settings.ai.provider.label".localized()) {
                Picker("", selection: $aiSettings.selectedProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .labelsHidden()
                .if(
                    ProcessInfo.processInfo.operatingSystemVersion.majorVersion
                        < 26
                ) { view in
                    view.fixedSize()
                }
                .onChange(of: aiSettings.selectedProvider) { _, _ in
                    // 提供商更改时无需额外操作
                }
            }
            .labeledContentStyle(.custom)

            LabeledContent("settings.ai.api_key.label".localized()) {
                Group {
                    if showApiKey {
                        TextField("".localized(), text: $aiSettings.apiKey)
                            .textFieldStyle(.roundedBorder).labelsHidden()
                    } else {
                        SecureField("".localized(), text: $aiSettings.apiKey)
                            .textFieldStyle(.roundedBorder).labelsHidden()
                    }
                }

                .onChange(of: aiSettings.apiKey) { _, _ in
                    // API Key 更改时无需额外操作
                }
                Button(action: {
                    showApiKey.toggle()
                }) {
                    Image(systemName: showApiKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
                .applyReplaceTransition()
            }
            .labeledContentStyle(.custom)
            
            // Ollama 地址设置（仅在选择 Ollama 时显示）
            if aiSettings.selectedProvider == .ollama {
                LabeledContent("settings.ai.ollama.url.label".localized()) {
                    TextField("http://localhost:11434", text: $aiSettings.ollamaBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .onChange(of: aiSettings.ollamaBaseURL) { _, _ in
                            // Ollama 地址更改时无需额外操作
                        }
                }
                .labeledContentStyle(.custom)
            }

        }
        .globalErrorHandler()
    }
}

#Preview {
    AISettingsView()
}
