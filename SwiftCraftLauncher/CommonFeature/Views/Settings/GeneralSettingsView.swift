//
//  GeneralSettingsView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A view for configuring general launcher settings.
public struct GeneralSettingsView: View {
    @Environment(DIContainer.self)
    private var container
    @State private var viewModel: GeneralSettingsViewModel
    @Environment(GameRepository.self)
    private var gameRepository

    @MainActor
    public init() {
        _viewModel = State(wrappedValue: GeneralSettingsViewModel())
    }

    public var body: some View {
        Form {
            GeneralSettingsLanguageRow(languageManager: container.ui.languageManager)

            GeneralSettingsThemeRow()
                .environment(container.ui.themeManager)

            GeneralSettingsInterfaceLayoutRow()
                .environment(container.ui.generalSettingsManager)

            GeneralSettingsWorkingDirectoryRow(
                viewModel: viewModel,
                gameRepository: gameRepository,
            )
            .environment(container.ui.generalSettingsManager)

            GeneralSettingsConcurrentDownloadsRow(
                viewModel: viewModel,
            )
            .environment(container.ui.generalSettingsManager)

            GeneralSettingsSystemProxyRow()

            GeneralSettingsCommonSheetHeightLimitRow()
                .environment(container.ui.generalSettingsManager)
        }
        .errorHandler(container.core.errorHandler)
        .onAppear {
            viewModel.configure(gameRepository: gameRepository)
        }
    }
}
