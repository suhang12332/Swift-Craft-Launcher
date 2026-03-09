import SwiftUI

/// 玩家状态管理器（单例）
class PlayerStatusManager: ObservableObject {
    static let shared = PlayerStatusManager()

    private init() {}
}

/// 显示玩家列表的视图
struct PlayerListView: View {
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
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
        }
        .buttonStyle(.borderless)
        .popover(isPresented: $showingPlayerListPopover, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(playerListViewModel.players) { player in
                    PlayerListItemView(player: player, playerListViewModel: playerListViewModel, playerToDelete: $playerToDelete, showDeleteAlert: $showDeleteAlert, showingPlayerListPopover: $showingPlayerListPopover)
                }
            }
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
    @StateObject private var statusManager = PlayerStatusManager.shared

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

// 列表项视图
private struct PlayerListItemView: View {
    let player: Player
    let playerListViewModel: PlayerListViewModel
    @Binding var playerToDelete: Player?
    @Binding var showDeleteAlert: Bool
    @Binding var showingPlayerListPopover: Bool
    @StateObject private var statusManager = PlayerStatusManager.shared

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
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

// PlayerAvatarView struct definition moved here
private struct PlayerAvatarView: View {
    let player: Player
    var size: CGFloat

    var body: some View {
        MinecraftSkinUtils(type: player.isRemote ? .url : .asset, src: player.avatarName, size: size)
            .id(player.id)
            .id(player.avatarName)
    }
}
