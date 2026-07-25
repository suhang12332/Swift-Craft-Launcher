//
//  AISettingsView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A view for configuring AI service settings.
public struct AISettingsView: View {
    @Environment(AISettingsManager.self)
    private var aiSettingsManager
    @State private var showApiKey = false

    public var body: some View {
        @Bindable var aiSettingsManager = aiSettingsManager
        Form {
            LabeledContent("settings.ai.api_type.label".localized()) {
                Picker("", selection: $aiSettingsManager.selectedProvider) {
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
                                TextField("".localized(), text: $aiSettingsManager.apiKey)
                                    .textFieldStyle(.roundedBorder).labelsHidden()
                            } else {
                                SecureField("".localized(), text: $aiSettingsManager.apiKey)
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
            if aiSettingsManager.selectedProvider == .ollama {
                LabeledContent("settings.ai.ollama.url.label".localized()) {
                    TextField(URLConfig.API.AIService.ollamaDefaultBaseURL, text: $aiSettingsManager.ollamaBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(maxWidth: 300)
                        .fixedSize()
                        .focusable(false)
                }
                .labeledContentStyle(.custom)
            }

            if aiSettingsManager.selectedProvider.apiFormat == .openAI {
                LabeledContent("settings.ai.api_url.label".localized()) {
                    TextField(aiSettingsManager.selectedProvider.baseURL, text: $aiSettingsManager.openAIBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: 300)
                        .fixedSize()
                        .focusable(false)
                }
                .labeledContentStyle(.custom)
            }

            LabeledContent("settings.ai.model.label".localized()) {
                TextField("settings.ai.model.placeholder".localized(), text: $aiSettingsManager.modelOverride)
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
                    src: aiSettingsManager.aiAvatarURL,
                    size: 42,
                )
                .padding(.leading, 2)
                Group {
                    LabeledContent("settings.ai.avatar.label".localized()) {
                        TextField("settings.ai.avatar.placeholder".localized(), text: $aiSettingsManager.aiAvatarURL)
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
