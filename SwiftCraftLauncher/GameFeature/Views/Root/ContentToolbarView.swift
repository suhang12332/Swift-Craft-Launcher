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
    @State private var isLoadingSkin = false
    @State private var preloadedSkinInfo: PlayerSkinService.PublicSkinInfo?
    @State private var preloadedProfile: MinecraftProfileResponse?

    // MARK: - Startup Info State
    @State private var showStartupInfo = false
    @State private var hasAnnouncement = false
    @State private var announcementData: AnnouncementData?
    @State private var hasCheckedAnnouncement = false

    // MARK: - Computed Properties

    /// 当前玩家（计算属性，避免重复访问）
    private var currentPlayer: Player? {
        playerListViewModel.currentPlayer
    }

    /// 是否为在线账户（计算属性）
    private var isCurrentPlayerOnline: Bool {
        currentPlayer?.isOnlineAccount ?? false
    }

    public var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                if currentPlayer == nil {
                    showPlayerAlert = true
                } else {
                    showingGameForm.toggle()
                }
            } label: {
                Label("game.form.title".localized(), systemImage: "plus")
            }
            .help("game.form.title".localized())
            .task {
                // 延迟检查公告，不阻塞初始渲染
                guard !hasCheckedAnnouncement else { return }
                hasCheckedAnnouncement = true
                // 使用低优先级任务在后台执行，不阻塞 UI 渲染
                Task(priority: .utility) {
                    await checkAnnouncement()
                }
            }
            .sheet(isPresented: $showingGameForm) {
                GameFormView()
                    .environmentObject(gameRepository)
                    .environmentObject(playerListViewModel)
                    .presentationBackgroundInteraction(.automatic)
            }
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
                        // 添加正版玩家
                        _ = playerListViewModel.addOnlinePlayer(profile: profile)

                        // 设置正版账户添加标记
                        PremiumAccountFlagManager.shared.setPremiumAccountAdded()

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

            // 皮肤管理按钮 - 仅在线账户显示
            if isCurrentPlayerOnline {
                Button {
                    Task {
                        await openSkinManager()
                    }
                } label: {
                    if isLoadingSkin {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("skin.title".localized(), systemImage: "tshirt")
                    }
                }
                .help("skin.title".localized())
                .disabled(isLoadingSkin)
                .sheet(isPresented: $showEditSkin) {
                    SkinToolDetailView(
                        preloadedSkinInfo: preloadedSkinInfo,
                        preloadedProfile: preloadedProfile
                    )
                    .onDisappear {
                        // 清理预加载的数据
                        preloadedSkinInfo = nil
                        preloadedProfile = nil
                    }
                }
            }

            // 启动信息按钮 - 仅在存在公告时显示
            if hasAnnouncement, let announcement = announcementData {
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

    // MARK: - Private Methods

    /// 打开皮肤管理器（先加载数据，再显示sheet）
    private func openSkinManager() async {
        guard let player = currentPlayer else { return }

        await MainActor.run {
            isLoadingSkin = true
        }

        // 如果是离线账户，直接使用，无需刷新token
        guard player.isOnlineAccount else {
            // 预加载皮肤数据
            async let skinInfo = PlayerSkinService.fetchCurrentPlayerSkinFromServices(player: player)
            async let profile = PlayerSkinService.fetchPlayerProfile(player: player)
            let (loadedSkinInfo, loadedProfile) = await (skinInfo, profile)

            await MainActor.run {
                preloadedSkinInfo = loadedSkinInfo
                preloadedProfile = loadedProfile
                isLoadingSkin = false
                showEditSkin = true
            }
            return
        }

        Logger.shared.info("打开皮肤管理器前验证玩家 \(player.name) 的Token")

        // 从 Keychain 按需加载认证凭据（只针对当前玩家，避免一次性读取所有账号）
        var playerWithCredential = player
        if playerWithCredential.credential == nil {
            let dataManager = PlayerDataManager()
            if let credential = dataManager.loadCredential(userId: playerWithCredential.id) {
                playerWithCredential.credential = credential
            }
        }

        // 使用已加载/更新后的玩家对象验证并尝试刷新Token
        let authService = MinecraftAuthService.shared
        let validatedPlayer: Player
        do {
            validatedPlayer = try await authService.validateAndRefreshPlayerTokenThrowing(for: playerWithCredential)

            // 如果Token被更新了，需要保存到PlayerDataManager
            if validatedPlayer.authAccessToken != player.authAccessToken {
                Logger.shared.info("玩家 \(player.name) 的Token已更新，保存到数据管理器")
                let dataManager = PlayerDataManager()
                let success = dataManager.updatePlayerSilently(validatedPlayer)
                if success {
                    Logger.shared.debug("已更新玩家数据管理器中的Token信息")
                    // 同步更新内存中的玩家列表（避免下次启动仍使用旧 token）
                    NotificationCenter.default.post(
                        name: PlayerSkinService.playerUpdatedNotification,
                        object: nil,
                        userInfo: ["updatedPlayer": validatedPlayer]
                    )
                }
            }
        } catch {
            Logger.shared.error("刷新Token失败: \(error.localizedDescription)")
            // Token刷新失败时，仍然尝试使用原有token加载皮肤数据
            validatedPlayer = playerWithCredential
        }

        // 预加载皮肤数据（使用验证后的玩家对象）
        async let skinInfo = PlayerSkinService.fetchCurrentPlayerSkinFromServices(player: validatedPlayer)
        async let profile = PlayerSkinService.fetchPlayerProfile(player: validatedPlayer)
        let (loadedSkinInfo, loadedProfile) = await (skinInfo, profile)

        await MainActor.run {
            preloadedSkinInfo = loadedSkinInfo
            preloadedProfile = loadedProfile
            isLoadingSkin = false
            showEditSkin = true
        }
    }

    /// 检查是否有公告
    /// 启动时只调用一次
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
