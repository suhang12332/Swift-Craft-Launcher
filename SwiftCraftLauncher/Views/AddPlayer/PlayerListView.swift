import SwiftUI

/// 玩家状态管理器（单例）
class PlayerStatusManager: ObservableObject {
    static let shared = PlayerStatusManager()

    @Published private var statusCache: [String: PlayerStatus] = [:]
    private var checkTasks: [String: Task<Void, Never>] = [:]

    private init() {}

    /// 获取玩家状态
    func getStatus(for player: Player) -> PlayerStatus {
        return statusCache[player.id] ?? .offline
    }

    /// 检查玩家状态
    func checkStatus(for player: Player) {
        // 取消之前的任务
        checkTasks[player.id]?.cancel()

        // 如果是离线账号，直接设置为离线状态（黄色）
        if !player.isOnlineAccount {
            statusCache[player.id] = .offline
            return
        }

        // 正版账户：如果 token 为空，视为过期（红色）
        if player.authAccessToken.isEmpty {
            statusCache[player.id] = .expired
            return
        }

        // 对于正版账户，异步检查 token 是否过期
        let task = Task {
            let authService = MinecraftAuthService.shared
            let isExpired = await authService.isTokenExpiredBasedOnTime(for: player)

            await MainActor.run {
                if isExpired {
                    statusCache[player.id] = .expired  // 红色：token 过期
                } else {
                    statusCache[player.id] = .valid    // 绿色：token 有效
                }
            }
        }

        checkTasks[player.id] = task
    }

    /// 玩家状态枚举
    enum PlayerStatus {
        case expired    // 红色：用户过期（正版）
        case valid      // 绿色：正常（正版）
        case offline    // 黄色：离线

        /// 获取状态对应的图标名称
        var iconName: String {
            switch self {
            case .expired:
                return "xmark.seal.fill"
            case .valid:
                return "checkmark.seal.fill"
            case .offline:
                return "checkmark.seal.fill"
            }
        }

        /// 获取状态对应的颜色
        var color: Color {
            switch self {
            case .expired:
                return .red
            case .valid:
                return .green
            case .offline:
                return .yellow
            }
        }
    }

    /// 获取玩家状态对应的图标名称
    func getStatusIconName(for player: Player) -> String {
        return getStatus(for: player).iconName
    }

    /// 获取玩家状态对应的颜色
    func getStatusColor(for player: Player) -> Color {
        return getStatus(for: player).color
    }
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
//            .frame(width: 200)
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

//                Spacer()
//
//                // 状态指示器（右对齐）
//                Image(systemName: statusManager.getStatusIconName(for: selectedPlayer))
//                    .font(.system(size: 12))
//                    .foregroundColor(statusManager.getStatusColor(for: selectedPlayer))
            }
            .onAppear {
                statusManager.checkStatus(for: selectedPlayer)
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
//            // 状态指示器（最左边）
//            Image(systemName: statusManager.getStatusIconName(for: player))
//                .font(.system(size: 12))
//                .foregroundColor(statusManager.getStatusColor(for: player))
//                .frame(width: 20)

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
                Image(systemName: "person.fill.xmark")
                    .help("player.remove".localized())
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .onAppear {
            statusManager.checkStatus(for: player)
        }
    }
}

// PlayerAvatarView struct definition moved here
private struct PlayerAvatarView: View {
    let player: Player
    var size: CGFloat

    var body: some View {
        MinecraftSkinUtils(type: player.isOnlineAccount ? .url : .asset, src: player.avatarName, size: size)
            .id(player.id)
            .id(player.avatarName)
    }
}
