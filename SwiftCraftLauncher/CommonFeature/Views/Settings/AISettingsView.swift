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

    public var body: some View {
        Form {
            AISettingsProviderRow()
                .id("settings.ai.api_type.label")
            AISettingsAPIKeyRow()
                .id("settings.ai.api_key.label")
            AISettingsURLSection()
                .id(aiSettingsManager.selectedProvider == .ollama
                    ? "settings.ai.ollama.url.label"
                    : "settings.ai.api_url.label")
            AISettingsModelRow()
                .id("settings.ai.model.label")
            Section {
                AISettingsAvatarRow()
                    .id("settings.ai.avatar.label")
                GameSettingsAICrashAnalysisRow()
                    .id("settings.ai_crash_analysis")
            }
        }
        .formStyle(.grouped)
    }
}
