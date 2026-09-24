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
    @State private var canAddOffline: Bool = false

    private var currentPlayer: Player? {
        playerListViewModel.currentPlayer
    }

    private var isMinecraftAccount: Bool {
        guard let p = currentPlayer else { return false }
        return p.isOnlineAccount
    }

    public var body: some View {
        Form {
            PlayerSettingsEphemeralLoginRow()
                .id("settings.player.ephemeral_login")
            if canAddOffline {
                PlayerSettingsOfflineLoginRow()
                    .id("settings.player.offline_login")
            }
            PlayerSettingsDefaultSkinServerRow()
                .id("settings.player.default_skin_server")
            if isMinecraftAccount {
                Section {
                    PlayerSettingsHistorySkinLibraryRow()
                        .id("settings.player.history_skin_library")
                    PlayerSettingsFriendsPresenceNotificationsRow()
                        .id("settings.player.minecraft_friends_presence_notifications")
                    PlayerSettingsMinecraftFriendsAccountSection(viewModel: viewModel)
                        .id("settings.player.minecraft_friends_account.section")
                }
            }
            Section {
                PlayerSettingsAuthlibInjectorRow(viewModel: viewModel)
                    .id("settings.player.authlib_injector")
            }
        }
        .formStyle(.grouped)
        .environment(playerSettingsManager)
        .task(id: currentPlayer?.id) {
            viewModel.refreshAuthlibInjectorExists()
            let container = DIContainer.shared.system
            canAddOffline = await container.premiumAccountFlagManager.canAddOfflineAccount(
                ipLocationService: container.ipLocationService,
            )
            guard let p = currentPlayer, p.isOnlineAccount else {
                viewModel.clearMinecraftFriendAccountPreferences()
                return
            }
            await viewModel.reloadMinecraftFriendAccountPreferences(currentPlayer: p)
        }
    }
}
