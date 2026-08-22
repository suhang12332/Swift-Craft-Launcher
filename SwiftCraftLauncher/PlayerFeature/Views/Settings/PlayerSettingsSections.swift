//
//  PlayerSettingsSections.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A row toggling ephemeral web login for player authentication.
struct PlayerSettingsEphemeralLoginRow: View {
    @Environment(PlayerSettingsManager.self)
    private var playerSettingsManager

    var body: some View {
        @Bindable var playerSettingsManager = playerSettingsManager
        LabeledContent("settings.player.ephemeral_login".localized()) {
            Toggle(
                "settings.player.ephemeral_login.toggle".localized(),
                isOn: $playerSettingsManager.enableEphemeralWebLogin,
            )
        }
        CommonDescriptionText(text: "settings.player.ephemeral_login.description".localized())
    }
}

/// A row toggling offline login for player authentication.
struct PlayerSettingsOfflineLoginRow: View {
    @Environment(PlayerSettingsManager.self)
    private var playerSettingsManager

    var body: some View {
        @Bindable var playerSettingsManager = playerSettingsManager
        LabeledContent("settings.player.offline_login".localized()) {
            Toggle(
                "settings.player.offline_login.toggle".localized(),
                isOn: $playerSettingsManager.enableOfflineLogin,
            )
        }
    }
}

/// A row for choosing the default Yggdrasil skin server.
struct PlayerSettingsDefaultSkinServerRow: View {
    @Environment(PlayerSettingsManager.self)
    private var playerSettingsManager
    private let yggdrasilServers = YggdrasilServerPresets.servers

    var body: some View {
        @Bindable var playerSettingsManager = playerSettingsManager
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
    }
}

/// A row toggling the history skin library for online accounts.
struct PlayerSettingsHistorySkinLibraryRow: View {
    @Environment(PlayerSettingsManager.self)
    private var playerSettingsManager

    var body: some View {
        @Bindable var playerSettingsManager = playerSettingsManager
        LabeledContent("settings.player.history_skin_library".localized()) {
            Toggle(
                "settings.player.history_skin_library.toggle".localized(),
                isOn: $playerSettingsManager.enableHistorySkinLibrary,
            )
        }
        CommonDescriptionText(text: "settings.player.history_skin_library.description".localized())
    }
}

/// A row toggling Minecraft friend presence notifications for online accounts.
struct PlayerSettingsFriendsPresenceNotificationsRow: View {
    @Environment(PlayerSettingsManager.self)
    private var playerSettingsManager

    var body: some View {
        @Bindable var playerSettingsManager = playerSettingsManager
        LabeledContent("settings.player.minecraft_friends_presence_notifications".localized()) {
            Toggle(
                "settings.player.minecraft_friends_presence_notifications.toggle".localized(),
                isOn: $playerSettingsManager.enableMinecraftFriendsPresenceNotifications,
            )
        }
        CommonDescriptionText(
            text: "settings.player.minecraft_friends_presence_notifications.description".localized(),
        )
    }
}

/// A section for managing the current online account's Minecraft friend preferences.
struct PlayerSettingsMinecraftFriendsAccountSection: View {
    @Environment(PlayerListViewModel.self)
    private var playerListViewModel
    @Bindable var viewModel: PlayerSettingsViewModel

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

    var body: some View {
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
        .padding(.bottom, 4)
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
    }
}

/// A row for downloading or updating the authlib-injector JAR.
struct PlayerSettingsAuthlibInjectorRow: View {
    @Bindable var viewModel: PlayerSettingsViewModel

    var body: some View {
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
    }
}
