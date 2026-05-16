import SwiftUI

public struct PlayerSettingsView: View {
    @StateObject private var playerSettings: PlayerSettingsManager
    @StateObject private var viewModel = PlayerSettingsViewModel()
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    private let yggdrasilServers = YggdrasilServerPresets.servers

    public init() {
        _playerSettings = StateObject(wrappedValue: AppServices.playerSettingsManager)
    }

    init(playerSettings: PlayerSettingsManager) {
        _playerSettings = StateObject(wrappedValue: playerSettings)
    }

    private var currentPlayer: Player? {
        playerListViewModel.currentPlayer
    }

    private var canEditMinecraftFriendAccountSettings: Bool {
        guard let p = currentPlayer else { return false }
        return p.isOnlineAccount
    }

    private var minecraftFriendAccountToggleDisabled: Bool {
        viewModel.minecraftFriendAccountPreferences == nil
            || viewModel.isLoadingMinecraftFriendAccountPreferences
            || viewModel.isSavingMinecraftFriendAccountPreferences
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
                Picker(
                    "",
                    selection: $playerSettings.defaultYggdrasilServerBaseURL
                ) {
                    Text("yggdrasil.server.please_select".localized())
                        .tag("")

                    ForEach(yggdrasilServers, id: \.baseURL) { server in
                        Text(server.name ?? server.baseURL.absoluteString)
                            .tag(server.baseURL.absoluteString)
                    }
                }
                .labelsHidden()
                .fixedSize()
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
            Group {
                LabeledContent("settings.player.minecraft_friends_presence_notifications".localized()) {
                    Toggle(
                        "settings.player.minecraft_friends_presence_notifications.toggle".localized(),
                        isOn: $playerSettings.enableMinecraftFriendsPresenceNotifications
                    )
                }
                .labeledContentStyle(.custom)
                CommonDescriptionText(
                    text: "settings.player.minecraft_friends_presence_notifications.description".localized()
                )
            }
            if canEditMinecraftFriendAccountSettings {
                Group {
                    LabeledContent("settings.player.minecraft_friends_account.section".localized()) {
                        if viewModel.isLoadingMinecraftFriendAccountPreferences {
                            ProgressView()
                                .scaleEffect(0.8)
                                .controlSize(.small)
                        } else if canEditMinecraftFriendAccountSettings {
                            Button("settings.player.minecraft_friends_account.reload_from_account".localized()) {
                                Task { await viewModel.reloadMinecraftFriendAccountPreferences(currentPlayer: currentPlayer) }
                            }
                            .disabled(viewModel.isSavingMinecraftFriendAccountPreferences)
                        }
                    }
                    .labeledContentStyle(.custom)
                    CommonDescriptionText(text: "settings.player.minecraft_friends_account.description".localized())
                    LabeledContent("") {
                        Toggle(
                            "settings.player.minecraft_friends_account.enable_friend_list".localized(),
                            isOn: Binding(
                                get: { viewModel.minecraftFriendAccountPreferences?.friends == .enabled },
                                set: { on in
                                    Task { await viewModel.setMinecraftFriendListEnabled(on, currentPlayer: currentPlayer) }
                                }
                            )
                        )
                        .disabled(minecraftFriendAccountToggleDisabled)
                    }
                    .labeledContentStyle(.customNoColon)
                    LabeledContent("") {
                        Toggle(
                            "settings.player.minecraft_friends_account.enable_accept_invites".localized(),
                            isOn: Binding(
                                get: { viewModel.minecraftFriendAccountPreferences?.acceptInvites == .enabled },
                                set: { on in
                                    Task { await viewModel.setMinecraftFriendAcceptInvitesEnabled(on, currentPlayer: currentPlayer) }
                                }
                            )
                        )
                        .disabled(minecraftFriendAccountToggleDisabled)
                    }
                    .labeledContentStyle(.customNoColon)
                }
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
        .task(id: currentPlayer?.id) {
            viewModel.refreshAuthlibInjectorExists()
            guard let p = currentPlayer, p.isOnlineAccount else {
                viewModel.clearMinecraftFriendAccountPreferences()
                return
            }
            await viewModel.reloadMinecraftFriendAccountPreferences(currentPlayer: p)
        }
    }
}
