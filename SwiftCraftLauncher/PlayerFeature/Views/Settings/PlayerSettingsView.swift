//
//  PlayerSettingsView.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays and manages player-related settings in the launcher configuration.
///
/// This view provides toggles for ephemeral login, offline login, skin library,
/// Minecraft friend presence notifications, and authlib-injector management.
public struct PlayerSettingsView: View {
    @Environment(PlayerSettingsManager.self)
    private var playerSettingsManager
    @State private var viewModel = PlayerSettingsViewModel()
    @Environment(PlayerListViewModel.self)
    private var playerListViewModel
    private let yggdrasilServers = YggdrasilServerPresets.servers

    private var currentPlayer: Player? {
        playerListViewModel.currentPlayer
    }

    private var isMinecraftAccount: Bool {
        guard let p = currentPlayer else { return false }
        return p.isOnlineAccount
    }

    private var minecraftFriendAccountToggleDisabled: Bool {
        viewModel.minecraftFriendAccountPreferences == nil
            || viewModel.isLoadingMinecraftFriendAccountPreferences
            || viewModel.isSavingMinecraftFriendAccountPreferences
    }

    public var body: some View {
        @Bindable var playerSettingsManager = playerSettingsManager

        Form {
            Group {
                LabeledContent("settings.player.ephemeral_login".localized()) {
                    Toggle(
                        "settings.player.ephemeral_login.toggle".localized(),
                        isOn: $playerSettingsManager.enableEphemeralWebLogin,
                    )
                }
                .labeledContentStyle(.custom)
                CommonDescriptionText(text: "settings.player.ephemeral_login.description".localized())
            }
            LabeledContent("settings.player.offline_login".localized()) {
                Toggle(
                    "settings.player.offline_login.toggle".localized(),
                    isOn: $playerSettingsManager.enableOfflineLogin,
                )
            }.labeledContentStyle(.custom)
            LabeledContent("settings.player.default_skin_server".localized()) {
                Picker(
                    "",
                    selection: $playerSettingsManager.defaultYggdrasilServerBaseURL,
                ) {
                    Text("yggdrasil.server.please_select".localized())
                        .tag("")

                    ForEach(yggdrasilServers, id: \.baseURL) { server in
                        Text(server.name)
                            .tag(server.baseURL.absoluteString)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .disabled(!playerSettingsManager.enableOfflineLogin)
            }
            .labeledContentStyle(.custom)
            if isMinecraftAccount {
                Group {
                    LabeledContent("settings.player.history_skin_library".localized()) {
                        Toggle(
                            "settings.player.history_skin_library.toggle".localized(),
                            isOn: $playerSettingsManager.enableHistorySkinLibrary,
                        )
                    }
                    .labeledContentStyle(.custom)
                    CommonDescriptionText(text: "settings.player.history_skin_library.description".localized())
                }
                Group {
                    LabeledContent("settings.player.minecraft_friends_presence_notifications".localized()) {
                        Toggle(
                            "settings.player.minecraft_friends_presence_notifications.toggle".localized(),
                            isOn: $playerSettingsManager.enableMinecraftFriendsPresenceNotifications,
                        )
                    }
                    .labeledContentStyle(.custom)
                    CommonDescriptionText(
                        text: "settings.player.minecraft_friends_presence_notifications.description".localized(),
                    )
                }
                Group {
                    LabeledContent("settings.player.minecraft_friends_account.section".localized()) {
                        if viewModel.isLoadingMinecraftFriendAccountPreferences {
                            ProgressView()
                                .scaleEffect(0.8)
                                .controlSize(.small)
                        } else if isMinecraftAccount {
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
                                },
                            ),
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
                                },
                            ),
                        )
                        .disabled(minecraftFriendAccountToggleDisabled)
                    }
                    .labeledContentStyle(.customNoColon)
                }
            }
            LabeledContent("settings.player.authlib_injector".localized()) {
                HStack(spacing: 8) {
                    if viewModel.authlibInjectorExists {
                        PathBreadcrumbView(path: AppConstants.AuthlibInjector.jarPath)
                    }
                    Button {
                        Task { await viewModel.downloadAuthlibInjector() }
                    } label: {
                        if viewModel.isDownloadingAuthlibInjector {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(viewModel.authlibInjectorExists ? "resource.update".localized() : "global_resource.download".localized())
                        }
                    }
                }
                .disabled(viewModel.isDownloadingAuthlibInjector)
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
