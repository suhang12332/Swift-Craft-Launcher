//
//  AISettingsView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A view for configuring AI service settings.
public struct AISettingsView: View {
    public var body: some View {
        Form {
            AISettingsProviderRow()
            AISettingsAPIKeyRow()
            AISettingsURLSection()
            AISettingsModelRow()
            spacerView()
            AISettingsAvatarRow()
        }
    }
}
