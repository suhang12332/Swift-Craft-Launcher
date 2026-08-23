//
//  AISettingsSections.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A row with a picker for the AI service provider.
struct AISettingsProviderRow: View {
    @Environment(AISettingsManager.self)
    private var aiSettingsManager

    var body: some View {
        @Bindable var aiSettingsManager = aiSettingsManager
        LabeledContent("settings.ai.api_type.label".localized()) {
            Picker("", selection: $aiSettingsManager.selectedProvider) {
                ForEach(AIProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
    }
}

/// A row for configuring the API key with a visibility toggle.
struct AISettingsAPIKeyRow: View {
    @Environment(AISettingsManager.self)
    private var aiSettingsManager
    @State private var showApiKey = false

    var body: some View {
        @Bindable var aiSettingsManager = aiSettingsManager
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
                Button(action: {
                    showApiKey.toggle()
                }, label: {
                    Image(systemName: showApiKey ? "eye.slash" : "eye")
                })
                .buttonStyle(.plain)
                .applyReplaceTransition()
            }
        }
        CommonDescriptionText(text: "settings.ai.api_key.description".localized())
    }
}

/// A row for configuring the Ollama base URL.
struct AISettingsOllamaURLRow: View {
    @Environment(AISettingsManager.self)
    private var aiSettingsManager

    var body: some View {
        @Bindable var aiSettingsManager = aiSettingsManager
        LabeledContent("settings.ai.ollama.url.label".localized()) {
            TextField(URLConfig.API.AIService.ollamaDefaultBaseURL, text: $aiSettingsManager.ollamaBaseURL)
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .frame(maxWidth: 300)
                .fixedSize()
        }
    }
}

/// A row for configuring the OpenAI-compatible base URL.
struct AISettingsAPIURLRow: View {
    @Environment(AISettingsManager.self)
    private var aiSettingsManager

    var body: some View {
        @Bindable var aiSettingsManager = aiSettingsManager
        LabeledContent("settings.ai.api_url.label".localized()) {
            TextField(aiSettingsManager.selectedProvider.baseURL, text: $aiSettingsManager.openAIBaseURL)
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .frame(width: 300)
                .fixedSize()
        }
    }
}

/// A section that shows the URL row matching the selected provider.
struct AISettingsURLSection: View {
    @Environment(AISettingsManager.self)
    private var aiSettingsManager

    var body: some View {
        switch aiSettingsManager.selectedProvider {
        case .ollama:
            AISettingsOllamaURLRow()
                .environment(aiSettingsManager)
        case .openai:
            AISettingsAPIURLRow()
                .environment(aiSettingsManager)
        }
    }
}

/// A row for configuring the model override.
struct AISettingsModelRow: View {
    @Environment(AISettingsManager.self)
    private var aiSettingsManager

    var body: some View {
        @Bindable var aiSettingsManager = aiSettingsManager
        LabeledContent("settings.ai.model.label".localized()) {
            TextField("settings.ai.model.placeholder".localized(), text: $aiSettingsManager.modelOverride)
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .frame(width: 180)
                .fixedSize()
                .focusable(false)
        }
    }
}

/// A row for configuring the AI avatar URL with a preview.
struct AISettingsAvatarRow: View {
    @Environment(AISettingsManager.self)
    private var aiSettingsManager

    var body: some View {
        @Bindable var aiSettingsManager = aiSettingsManager
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
            }
            CommonDescriptionText(text: "settings.ai.avatar.description".localized())
        }
        .padding(.leading, 2)
    }
}
