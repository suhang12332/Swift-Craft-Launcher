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
            if canAddOffline {
                PlayerSettingsOfflineLoginRow()
            }
            PlayerSettingsDefaultSkinServerRow()
            spacerView()
            if isMinecraftAccount {
                PlayerSettingsHistorySkinLibraryRow()
                PlayerSettingsFriendsPresenceNotificationsRow()
                PlayerSettingsMinecraftFriendsAccountSection(viewModel: viewModel)
                spacerView()
            }
            PlayerSettingsAuthlibInjectorRow(viewModel: viewModel)
        }
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
