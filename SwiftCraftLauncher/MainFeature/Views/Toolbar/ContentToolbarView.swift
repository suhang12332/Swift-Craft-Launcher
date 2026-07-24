//
//  ContentToolbarView.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import MinecraftFriendsKit
import SwiftUI

/// Provides the primary toolbar content for the main content area.
public struct ContentToolbarView: ToolbarContent {
    @Environment(DIContainer.self)
    private var container
    @Environment(PlayerListViewModel.self)
    private var playerListViewModel
    @Environment(GameRepository.self)
    private var gameRepository

    @State private var viewModel = ContentToolbarViewModel()
    @State private var minecraftFriendsSheetViewModel = MinecraftFriendsSheetViewModel(
        friendsService: DIContainer.shared.ui.minecraftFriendsService,
    )

    private var currentPlayer: Player? {
        playerListViewModel.currentPlayer
    }

    private var isCurrentPlayerOnline: Bool {
        currentPlayer?.isOnlineAccount ?? false
    }

    public var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            AddGameToolbarButton(currentPlayer: currentPlayer)

            Spacer()

            AddPlayerToolbarButton()

            if isCurrentPlayerOnline {
                SkinToolbarButton(
                    isLoadingSkin: viewModel.isLoadingSkin,
                    currentPlayer: currentPlayer,
                    viewModel: viewModel,
                )

                MinecraftFriendsToolbarButton(
                    currentPlayer: currentPlayer,
                    viewModel: minecraftFriendsSheetViewModel,
                )
            }
        }
    }
}
