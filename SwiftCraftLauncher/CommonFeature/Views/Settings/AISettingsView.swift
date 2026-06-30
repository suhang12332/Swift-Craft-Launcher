//
//  AISettingsView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A view for configuring AI service settings.
public struct AISettingsView: View {
    @StateObject private var aiSettings: AISettingsManager
    @State private var showApiKey = false

    public init() {
        _aiSettings = StateObject(wrappedValue: AppServices.aiSettingsManager)
    }

    init(aiSettings: AISettingsManager) {
        _aiSettings = StateObject(wrappedValue: aiSettings)
    }

    public var body: some View {
        Form {
            LabeledContent("settings.ai.api_type.label".localized()) {
                Picker("", selection: $aiSettings.selectedProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            .labeledContentStyle(.custom)

            Group {
                LabeledContent("settings.ai.api_key.label".localized()) {
                    HStack {
                        Group {
                            if showApiKey {
                                TextField("".localized(), text: $aiSettings.apiKey)
                                    .textFieldStyle(.roundedBorder).labelsHidden()
                            } else {
                                SecureField("".localized(), text: $aiSettings.apiKey)
                                    .textFieldStyle(.roundedBorder).labelsHidden()
                            }
                        }
                        .frame(width: 300)
                        .focusable(false)
                        Button(action: {
                            showApiKey.toggle()
                        }, label: {
                            Image(systemName: showApiKey ? "eye.slash" : "eye")
                        })
                        .buttonStyle(.plain)
                        .applyReplaceTransition()
                    }
                }
                .labeledContentStyle(.custom)
                CommonDescriptionText(text: "settings.ai.api_key.description".localized())
            }
            if aiSettings.selectedProvider == .ollama {
                LabeledContent("settings.ai.ollama.url.label".localized()) {
                    TextField(URLConfig.API.AIService.ollamaDefaultBaseURL, text: $aiSettings.ollamaBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(maxWidth: 300)
                        .fixedSize()
                        .focusable(false)
                }
                .labeledContentStyle(.custom)
            }

            if aiSettings.selectedProvider.apiFormat == .openAI {
                LabeledContent("settings.ai.api_url.label".localized()) {
                    TextField(aiSettings.selectedProvider.baseURL, text: $aiSettings.openAIBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: 180)
                        .fixedSize()
                        .focusable(false)
                }
                .labeledContentStyle(.custom)
            }

            LabeledContent("settings.ai.model.label".localized()) {
                TextField("settings.ai.model.placeholder".localized(), text: $aiSettings.modelOverride)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: 180)
                    .fixedSize()
                    .focusable(false)
            }
            .labeledContentStyle(.custom)

            Group {
                MinecraftSkinUtils(
                    type: .url,
                    src: aiSettings.aiAvatarURL,
                    size: 42,
                )
                .padding(.leading, 2)
                Group {
                    LabeledContent("settings.ai.avatar.label".localized()) {
                        TextField("settings.ai.avatar.placeholder".localized(), text: $aiSettings.aiAvatarURL)
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                            .frame(maxWidth: 300)
                            .fixedSize()
                            .focusable(false)
                    }
                    .labeledContentStyle(.custom)
                    CommonDescriptionText(text: "settings.ai.avatar.description".localized())
                }
                .padding(.leading, 2)
            }
        }
    }
}
