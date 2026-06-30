//
//  GeneralSettingsView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A view for configuring general launcher settings.
public struct GeneralSettingsView: View {
    @StateObject private var generalSettings: GeneralSettingsManager
    @StateObject private var themeManager: ThemeManager
    @StateObject private var viewModel: GeneralSettingsViewModel
    @EnvironmentObject private var gameRepository: GameRepository

    @MainActor
    public init() {
        _generalSettings = StateObject(wrappedValue: AppServices.generalSettingsManager)
        _themeManager = StateObject(wrappedValue: AppServices.themeManager)
        _viewModel = StateObject(wrappedValue: GeneralSettingsViewModel())
    }

    public var body: some View {
        Form {
            GeneralSettingsLanguageRow()
            GeneralSettingsThemeRow(themeManager: themeManager)
            GeneralSettingsInterfaceLayoutRow(generalSettings: generalSettings)
            GeneralSettingsWorkingDirectoryRow(
                generalSettings: generalSettings,
                viewModel: viewModel,
                gameRepository: gameRepository,
            )
            GeneralSettingsConcurrentDownloadsRow(
                generalSettings: generalSettings,
                viewModel: viewModel,
            )
            GeneralSettingsSystemProxyRow()
            GeneralSettingsGitHubProxyRow(generalSettings: generalSettings)
            GeneralSettingsCommonSheetHeightLimitRow(generalSettings: generalSettings)
        }
        .errorHandler()
        .onAppear {
            viewModel.configure(gameRepository: gameRepository)
        }
        .alert(
            "error.notification.validation.title".localized(),
            isPresented: .constant(viewModel.error != nil && viewModel.error?.level == .popup),
        ) {
            Button("common.close".localized()) {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
}
