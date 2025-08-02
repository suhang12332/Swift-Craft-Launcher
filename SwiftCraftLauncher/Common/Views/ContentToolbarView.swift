import SwiftUI

/// 内容区域工具栏内容
public struct ContentToolbarView: ToolbarContent {
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @State private var showingAddPlayerSheet = false
    @State private var playerName = ""
    @State private var isPlayerNameValid = false

    public var body: some ToolbarContent {
        ToolbarItemGroup {
            // 显示玩家列表（如有玩家）
            if !playerListViewModel.players.isEmpty {
                PlayerListView()
                Spacer()
            }
            // 添加玩家按钮
            Button(action: {
                playerName = ""
                isPlayerNameValid = false
                showingAddPlayerSheet = true
            }) {
                Label("player.add".localized(), systemImage: "person.badge.plus")
            }
            .help("player.add".localized())
            .sheet(isPresented: $showingAddPlayerSheet) {
                AddPlayerSheetView(
                    playerName: $playerName,
                    isPlayerNameValid: $isPlayerNameValid,
                    onAdd: {
                        if playerListViewModel.addPlayer(name: playerName) {
                            Logger.shared.debug("玩家 \(playerName) 添加成功 (通过 ViewModel)。")
                        } else {
                            Logger.shared.debug("添加玩家 \(playerName) 失败 (通过 ViewModel)。")
                        }
                        isPlayerNameValid = true
                        showingAddPlayerSheet = false
                    },
                    onCancel: {
                        playerName = ""
                        isPlayerNameValid = false
                        showingAddPlayerSheet = false
                    },
                    onLogin: { profile in
                        // 处理正版登录成功，使用Minecraft用户资料
                        Logger.shared.debug("正版登录成功，用户: \(profile.name)")
                        // 这里可以添加正版玩家的处理逻辑
                        let _ = playerListViewModel.addOnlinePlayer(profile: profile)
                        showingAddPlayerSheet = false
                    },
                    playerListViewModel: playerListViewModel
                )
            }
        }
    }
}

