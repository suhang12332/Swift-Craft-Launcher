import SwiftUI

/// 内容区域工具栏内容
public struct ContentToolbarView: ToolbarContent {
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @State private var showingAddPlayerSheet = false
    @State private var playerName = ""
    @State private var isPlayerNameValid = false
    @State private var showPlayerAlert = false
    @State private var showingGameForm = false
    @EnvironmentObject var gameRepository: GameRepository

    
    public var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: {
                if playerListViewModel.currentPlayer == nil {
                    showPlayerAlert = true
                } else {
                    showingGameForm.toggle()
                }
            }) {
                Label("game.form.title".localized(), systemImage: "plus")
            }.help("game.form.title".localized())
            
            // 后台下载 待实现
//            Button(action: {
//                
//            }) {
//                Label("game.form.title".localized(), systemImage: "square.and.arrow.down.badge.clock")
//                                Label("game.form.title".localized(), systemImage: "icloud.and.arrow.down.fill")
//                
//            }
            
            
            
            Spacer()
            
            // 添加玩家按钮
            Button(action: {
                playerName = ""
                isPlayerNameValid = false
                showingAddPlayerSheet = true
            }) {
                Label("player.add".localized(), systemImage: "person.badge.plus")
            }.help("player.add".localized())
            
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
                    onYggLogin: { profile in
                        Logger.shared.debug("Yggdrasil登录成功!")
                    },
                    playerListViewModel: playerListViewModel
                )
            }
            
            .sheet(isPresented: $showingGameForm) {
                GameFormView()
                    .environmentObject(gameRepository)
                    .environmentObject(playerListViewModel)
                    .presentationDetents([.medium, .large])
                    .presentationBackgroundInteraction(.automatic)
            }
            .alert(isPresented: $showPlayerAlert) {
                Alert(
                    title: Text("sidebar.alert.no_player.title".localized()),
                    message: Text("sidebar.alert.no_player.message".localized()),
                    dismissButton: .default(Text("common.confirm".localized()))
                )
            }
        }
    }
}

