import SwiftUI

public struct PlayerSettingsView: View {
    @StateObject private var playerSettings: PlayerSettingsManager
    @StateObject private var viewModel = PlayerSettingsViewModel()
    private let yggdrasilServers = YggdrasilServerPresets.servers

    public init() {
        _playerSettings = StateObject(wrappedValue: AppServices.playerSettingsManager)
    }

    init(playerSettings: PlayerSettingsManager) {
        _playerSettings = StateObject(wrappedValue: playerSettings)
    }

    public var body: some View {
        let authlibInjectorJarURL = AppPaths.authDirectory.appendingPathComponent(AppConstants.AuthlibInjector.jarFileName)

        Form {
            LabeledContent("settings.player.offline_login".localized()) {
                Toggle(
                    "settings.player.offline_login.toggle".localized(),
                    isOn: $playerSettings.enableOfflineLogin
                )
            }.labeledContentStyle(.custom)
            LabeledContent("settings.player.default_skin_server".localized()) {
                CommonMenuPicker(
                    selection: $playerSettings.defaultYggdrasilServerBaseURL,
                    hidesLabel: true
                ) {
                    Text("")
                } content: {
                    Text(paddedPickerLabel("yggdrasil.server.please_select".localized()))
                        .tag("")

                    ForEach(yggdrasilServers, id: \.baseURL) { server in
                        Text(paddedPickerLabel(server.name ?? server.baseURL.absoluteString))
                            .tag(server.baseURL.absoluteString)
                    }
                }
                .disabled(!playerSettings.enableOfflineLogin)
            }
            .labeledContentStyle(.custom)
            Group {
                LabeledContent("settings.player.history_skin_library".localized()) {
                    Toggle(
                        "settings.player.history_skin_library.toggle".localized(),
                        isOn: $playerSettings.enableHistorySkinLibrary
                    )
                }
                .labeledContentStyle(.custom)
                CommonDescriptionText(text: "settings.player.history_skin_library.description".localized())
            }
            LabeledContent("settings.player.authlib_injector".localized()) {
                if viewModel.authlibInjectorExists {
                    PathBreadcrumbView(path: authlibInjectorJarURL.path)
                } else {
                    Button {
                        Task { await viewModel.downloadAuthlibInjector() }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isDownloadingAuthlibInjector {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("global_resource.download".localized())
                            }
                        }
                    }
                    .disabled(viewModel.isDownloadingAuthlibInjector)
                }
            }
            .labeledContentStyle(.custom)
            .padding(.top, 10)
        }
        .task {
            viewModel.refreshAuthlibInjectorExists()
        }
    }
}
