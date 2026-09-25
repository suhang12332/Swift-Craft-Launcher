//
//  GeneralSettingsView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Renders the launcher's general settings.
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
            Section {
                GeneralSettingsLanguageRow(languageManager: container.ui.languageManager)
                SettingsThemeRow()
                    .environment(container.ui.themeManager)
                GeneralSettingsInterfaceLayoutRow()
                    .environment(container.ui.generalSettingsManager)
            }
            Section {
                SettingsWorkingDirectoryRow(
                    viewModel: viewModel,
                    gameRepository: gameRepository,
                )
                .environment(container.ui.generalSettingsManager)
            }
            Section {
                GeneralSettingsSystemProxyRow()
                GeneralSettingsCommonSheetHeightLimitRow()
                    .environment(container.ui.generalSettingsManager)
            }
        }
        .formStyle(.grouped)
        .contentMargins(.top, 0, for: .scrollContent)
        .errorHandler(container.core.errorHandler)
        .onAppear {
            viewModel.configure(gameRepository: gameRepository)
        }
    }
}
