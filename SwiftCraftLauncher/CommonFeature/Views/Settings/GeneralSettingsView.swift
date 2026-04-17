import SwiftUI

public struct GeneralSettingsView: View {
    @StateObject private var generalSettings = GeneralSettingsManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var viewModel = GeneralSettingsViewModel()
    @EnvironmentObject private var gameRepository: GameRepository

    public init() {}

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
        .globalErrorHandler()
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

#Preview {
    GeneralSettingsView()
}
