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
    @State private var showEditSkin = false

    // MARK: - Startup Info State
    @State private var showStartupInfo = false
    @State private var hasAnnouncement = false
    @State private var announcementData: AnnouncementData?

    public var body: some ToolbarContent {
        Group {
            ToolbarItemGroup(placement: .primaryAction) {
            Button {
                if playerListViewModel.currentPlayer == nil {
                    showPlayerAlert = true
                } else {
                    showingGameForm.toggle()
                }
            } label: {
                Label("game.form.title".localized(), systemImage: "plus")
            }
            .help("game.form.title".localized())
            .task {
                // 在视图出现时检查公告
                await checkAnnouncement()
            }
            .sheet(isPresented: $showingGameForm) {
                GameFormView()
                    .environmentObject(gameRepository)
                    .environmentObject(playerListViewModel)
                    .presentationBackgroundInteraction(.automatic)
            }

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
                            // 延迟清理认证状态，避免影响对话框关闭动画
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                MinecraftAuthService.shared.clearAuthenticationData()
                            }
                        },
                        onLogin: { profile in
                            // 处理正版登录成功，使用Minecraft用户资料
                            Logger.shared.debug("正版登录成功，用户: \(profile.name)")
                            // 这里可以添加正版玩家的处理逻辑
                            _ = playerListViewModel.addOnlinePlayer(profile: profile)

                            showingAddPlayerSheet = false
                            // 延迟清理认证状态，让用户能看到成功状态
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                MinecraftAuthService.shared.clearAuthenticationData()
                            }
                        },

                        playerListViewModel: playerListViewModel
                    )
                }
                .alert(isPresented: $showPlayerAlert) {
                    Alert(
                        title: Text("sidebar.alert.no_player.title".localized()),
                        message: Text("sidebar.alert.no_player.message".localized()),
                        dismissButton: .default(Text("common.confirm".localized()))
                    )
                }
                if let player = playerListViewModel.currentPlayer, player.isOnlineAccount {
                    Button {
                        showEditSkin = true
                    } label: {
                        Label("skin.title".localized(), systemImage: "tshirt")
                            .help("skin.title".localized())
                    }
                    .sheet(isPresented: $showEditSkin) {
                        SkinToolDetailView()
                    }
                }
            }

            // 启动信息按钮 - 作为单独的 ToolbarItem，仅在存在公告时显示
            if hasAnnouncement, let announcement = announcementData {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showStartupInfo = true
                    } label: {
                        Label(announcement.title, systemImage: "bell.badge")
                            .labelStyle(.iconOnly)
                    }
                    .help(announcement.title)
                    .sheet(isPresented: $showStartupInfo) {
                        StartupInfoSheetView(announcementData: announcementData)
                    }
                }
            }
        }
    }

    // MARK: - Private Methods

    /// 检查是否有公告
    private func checkAnnouncement() async {
        let version = Bundle.main.appVersion
        let language = LanguageManager.shared.selectedLanguage.isEmpty
            ? LanguageManager.getDefaultLanguage()
            : LanguageManager.shared.selectedLanguage

        do {
            let data = try await GitHubService.shared.fetchAnnouncement(
                version: version,
                language: language
            )

            await MainActor.run {
                if let data = data {
                    self.hasAnnouncement = true
                    self.announcementData = data
                } else {
                    self.hasAnnouncement = false
                    self.announcementData = nil
                }
            }
        } catch {
            await MainActor.run {
                self.hasAnnouncement = false
                self.announcementData = nil
            }
        }
    }
}
