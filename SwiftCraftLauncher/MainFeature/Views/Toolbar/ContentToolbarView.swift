import SwiftUI

/// 内容区域工具栏内容
public struct ContentToolbarView: ToolbarContent {
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @State private var showingAddPlayerSheet = false
    @State private var playerName = ""
    @State private var isPlayerNameValid = false
    @State private var showPlayerAlert = false
    @State private var showingGameForm = false
    @EnvironmentObject private var gameRepository: GameRepository
    @State private var showEditSkin = false
    @StateObject private var viewModel = ContentToolbarViewModel()
    private let minecraftAuthService: MinecraftAuthService
    private let yggdrasilAuthService: YggdrasilAuthService
    private let premiumAccountFlagManager: PremiumAccountFlagManager

    init(
        minecraftAuthService: MinecraftAuthService = AppServices.minecraftAuthService,
        yggdrasilAuthService: YggdrasilAuthService = AppServices.yggdrasilAuthService,
        premiumAccountFlagManager: PremiumAccountFlagManager = AppServices.premiumAccountFlagManager
    ) {
        self.minecraftAuthService = minecraftAuthService
        self.yggdrasilAuthService = yggdrasilAuthService
        self.premiumAccountFlagManager = premiumAccountFlagManager
    }

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
                            minecraftAuthService.clearAuthenticationData()
                        }
                    },
                    onLogin: { profile in
                        Logger.shared.debug("正版登录成功，用户: \(profile.name)")
                        _ = playerListViewModel.addOnlinePlayer(profile: profile)
                        premiumAccountFlagManager.setPremiumAccountAdded()
                        showingAddPlayerSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            minecraftAuthService.clearAuthenticationData()
                        }
                    },
                    onYggdrasilLogin: { profile in
                        Logger.shared.debug("Yggdrasil 登录成功，用户: \(profile.name)")
                        // 绑定该三方账号的认证/皮肤服务器基地址，供启动时注入 authlib-injector 使用
                        OfflineUserServerMap.setServer(profile.serverBaseURL, for: profile.id)
                        _ = playerListViewModel.addOnlinePlayer(profile: profile)
                        showingAddPlayerSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            yggdrasilAuthService.logout()
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
                        await viewModel.preloadSkinDataForManager(player: currentPlayer)
                        if currentPlayer != nil, !Task.isCancelled {
                            showEditSkin = true
                        }
                    }
                } label: {
                    if viewModel.isLoadingSkin {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("skin.title".localized(), systemImage: "tshirt")
                    }
                }
                .help("skin.title".localized())
                .disabled(viewModel.isLoadingSkin)
                .sheet(isPresented: $showEditSkin) {
                    SkinToolDetailView(
                        preloadedSkinInfo: viewModel.preloadedSkinInfo,
                        preloadedProfile: viewModel.preloadedProfile
                    )
                    .onDisappear {
                        viewModel.clearPreloadedSkinData()
                    }
                }
            }
        }
    }
}
