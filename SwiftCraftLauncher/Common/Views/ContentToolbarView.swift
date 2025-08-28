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

    // MARK: - Startup Info State
    @State private var showStartupInfo = false

    public var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                if playerListViewModel.currentPlayer == nil {
                    showPlayerAlert = true
                } else {
                    showingGameForm.toggle()
                }
            } label: {
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
            Button {
                playerName = ""
                isPlayerNameValid = false
                showingAddPlayerSheet = true
            } label: {
                Label("player.add".localized(), systemImage: "person.badge.plus")
            }
            .help("player.add".localized())

            // 启动信息按钮
            Button {
                showStartupInfo = true
            } label: {
                Label("startup.info.title".localized(), systemImage: "bell.badge")
            }
            .help("startup.info.title".localized())

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

                        // 清理微软认证服务的内存信息
                        MinecraftAuthService.shared.clearAuthenticationData()

                        showingAddPlayerSheet = false
                    },
                    onLogin: { profile in
                        // 处理正版登录成功，使用Minecraft用户资料
                        Logger.shared.debug("正版登录成功，用户: \(profile.name)")
                        // 这里可以添加正版玩家的处理逻辑
                        let _ = playerListViewModel.addOnlinePlayer(profile: profile)

                        // 清理微软认证服务的内存信息，防止下次添加账户时显示上一次的结果
                        MinecraftAuthService.shared.clearAuthenticationData()

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
            .sheet(isPresented: $showStartupInfo) {
                StartupInfoSheetView()
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
