//
//  GeneralSettingsView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Renders the general, appearance, files, or network settings for the selected page.
public struct GeneralSettingsView: View {
    let page: SettingsPage
    @Environment(DIContainer.self)
    private var container
    @State private var viewModel: GeneralSettingsViewModel
    @Environment(GameRepository.self)
    private var gameRepository

    @MainActor
    init(page: SettingsPage) {
        self.page = page
        _viewModel = State(wrappedValue: GeneralSettingsViewModel())
    }

    public var body: some View {
        Form {
            switch page {
            case .general:
                Section {
                    GeneralSettingsLanguageRow(languageManager: container.ui.languageManager)
                    GeneralSettingsCommonSheetHeightLimitRow()
                        .environment(container.ui.generalSettingsManager)
                }
            case .appearance:
                Section {
                    GeneralSettingsThemeRow()
                        .environment(container.ui.themeManager)
                    GeneralSettingsInterfaceLayoutRow()
                        .environment(container.ui.generalSettingsManager)
                }
            case .files:
                Section {
                    GeneralSettingsWorkingDirectoryRow(
                        viewModel: viewModel,
                        gameRepository: gameRepository,
                    )
                    .environment(container.ui.generalSettingsManager)
                }
            case .network:
                Section {
                    GeneralSettingsSystemProxyRow()
                    GameSettingsAPISourceRow()
                }
            default:
                EmptyView()
            }
        }
        .formStyle(.grouped)
        .errorHandler(container.core.errorHandler)
        .onAppear {
            viewModel.configure(gameRepository: gameRepository)
        }
    }
}
