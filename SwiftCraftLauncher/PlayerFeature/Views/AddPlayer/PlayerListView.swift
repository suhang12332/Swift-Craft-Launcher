//
//  PlayerListView.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays a player list popover with selection and deletion capabilities.
struct PlayerListView: View {
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @Environment(\.dismiss)
    var dismiss
    @State private var playerToDelete: Player?
    @State private var showDeleteAlert = false
    @State private var showingPlayerListPopover = false

    var body: some View {
        Button {
            showingPlayerListPopover.toggle()
        } label: {
            PlayerSelectorLabel(selectedPlayer: playerListViewModel.currentPlayer)
                .applyPointerHandIfAvailable()
        }
        .buttonStyle(.borderless)
        .popover(isPresented: $showingPlayerListPopover, arrowEdge: .top) {
            ForEach(playerListViewModel.players) { player in
                PlayerListItemView(player: player, playerListViewModel: playerListViewModel, playerToDelete: $playerToDelete, showDeleteAlert: $showDeleteAlert, showingPlayerListPopover: $showingPlayerListPopover)
            }
            .padding()
        }
        .confirmationDialog(
            "player.remove".localized(),
            isPresented: $showDeleteAlert,
            titleVisibility: .visible
        ) {
            Button("player.remove".localized(), role: .destructive) {
                if let player = playerToDelete {
                    _ = playerListViewModel.deletePlayer(byID: player.id)
                }
                playerToDelete = nil
            }.keyboardShortcut(.defaultAction)
            Button("common.cancel".localized(), role: .cancel) {
                playerToDelete = nil
            }
        } message: {
            Text(String(format: "player.remove.confirm".localized(), playerToDelete?.name ?? ""))
        }
    }
}

private struct PlayerSelectorLabel: View {
    let selectedPlayer: Player?

    var body: some View {
        if let selectedPlayer = selectedPlayer {
            HStack(spacing: 8) {
                PlayerAvatarView(player: selectedPlayer, size: 32)
                Text(selectedPlayer.name)
                    .foregroundColor(.primary)
                    .font(.system(size: 13).bold())
                    .lineLimit(1)
            }
        } else {
            EmptyView()
        }
    }
}

private struct PlayerListItemView: View {
    let player: Player
    let playerListViewModel: PlayerListViewModel
    @Binding var playerToDelete: Player?
    @Binding var showDeleteAlert: Bool
    @Binding var showingPlayerListPopover: Bool

    var body: some View {
        HStack {
            Button {
                playerListViewModel.setCurrentPlayer(byID: player.id)
                showingPlayerListPopover = false
            } label: {
                PlayerAvatarView(player: player, size: 36)
                Text(player.name)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 64)
            Button {
                playerToDelete = player
                showDeleteAlert = true
            } label: {
                Image(systemName: "trash.fill")
                    .help("player.remove".localized())
            }
            .buttonStyle(.borderless)
        }
    }
}

private struct PlayerAvatarView: View {
    let player: Player
    var size: CGFloat

    var body: some View {
        MinecraftSkinUtils(type: player.isRemote ? .url : .asset, src: player.avatarName, size: size)
            .id(player.id)
            .id(player.avatarName)
    }
}
