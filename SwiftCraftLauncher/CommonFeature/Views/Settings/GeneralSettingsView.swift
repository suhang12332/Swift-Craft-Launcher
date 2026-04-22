import SwiftUI

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

    @MainActor
    init(
        generalSettings: GeneralSettingsManager,
        themeManager: ThemeManager,
        viewModel: GeneralSettingsViewModel
    ) {
        _generalSettings = StateObject(wrappedValue: generalSettings)
        _themeManager = StateObject(wrappedValue: themeManager)
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        Form {
            GeneralSettingsLanguageRow()
            GeneralSettingsThemeRow(themeManager: themeManager)
            GeneralSettingsInterfaceLayoutRow(generalSettings: generalSettings)
            GeneralSettingsWorkingDirectoryRow(
                generalSettings: generalSettings,
                viewModel: viewModel,
                gameRepository: gameRepository
            )
            GeneralSettingsConcurrentDownloadsRow(
                generalSettings: generalSettings,
                viewModel: viewModel
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
            isPresented: .constant(viewModel.error != nil && viewModel.error?.level == .popup)
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
