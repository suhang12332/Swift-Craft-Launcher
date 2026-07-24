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

    @State private var showingAddPlayerSheet = false
    @State private var playerName = ""
    @State private var isPlayerNameValid = false
    @State private var showingGameForm = false
    @State private var showEditSkin = false
    @State private var showingMinecraftFriendsSheet = false
    @State private var minecraftFriendsSheetHost: MinecraftFriendsSheetHostAdapter?
    @State private var isLoadingFriends = false
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
            AddGameToolbarButton(
                showingGameForm: $showingGameForm,
                currentPlayer: currentPlayer,
            )

            Spacer()

            AddPlayerToolbarButton(
                showingAddPlayerSheet: $showingAddPlayerSheet,
                playerName: $playerName,
                isPlayerNameValid: $isPlayerNameValid,
            )

            if isCurrentPlayerOnline {
                SkinToolbarButton(
                    showEditSkin: $showEditSkin,
                    isLoadingSkin: viewModel.isLoadingSkin,
                    currentPlayer: currentPlayer,
                    viewModel: viewModel,
                )

                MinecraftFriendsToolbarButton(
                    showingMinecraftFriendsSheet: $showingMinecraftFriendsSheet,
                    minecraftFriendsSheetHost: $minecraftFriendsSheetHost,
                    isLoadingFriends: $isLoadingFriends,
                    currentPlayer: currentPlayer,
                    viewModel: minecraftFriendsSheetViewModel,
                )
            }
        }
    }
}
