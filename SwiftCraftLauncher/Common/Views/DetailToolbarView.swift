import SwiftUI

/// 详情区域工具栏内容
public struct DetailToolbarView: ToolbarContent {
    @Binding var selectedItem: SidebarItem
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @Binding var gameResourcesType: String
    @Binding var gameType: Bool  // false = local, true = server
    @Binding var versionCurrentPage: Int
    @Binding var versionTotal: Int
    @EnvironmentObject var gameRepository: GameRepository
    @StateObject private var gameStatusManager = GameStatusManager.shared
    @StateObject private var gameActionManager = GameActionManager.shared
    @StateObject private var gameSettings = GameSettingsManager.shared
    @Binding var project: ModrinthProjectDetail?
    @Binding var selectProjectId: String?
    @Binding var selectedTab: Int
    @Binding var gameId: String?
    @Binding var dataSource: DataSource
    @Binding var localResourceFilter: LocalResourceFilter

    // MARK: - Computed Properties

    private var currentGame: GameVersionInfo? {
        if case .game(let gameId) = selectedItem {
            return gameRepository.getGame(by: gameId)
        }
        return nil
    }

    /// 基于进程状态判断游戏是否正在运行
    private func isGameRunning(gameId: String) -> Bool {
        return gameStatusManager.isGameRunning(gameId: gameId)
    }

    public var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            switch selectedItem {
            case .game:
                if let game = currentGame {
                    resourcesTypeMenu
                    resourcesMenu
                    // 仅在本地资源视图下显示“全部 / 已禁用”筛选
                    if !gameType {
                        localResourceFilterMenu
                    }
                    if gameType {
                        dataSourceMenu
                    }

                    Spacer()

                    Button {
                        Task {
                            let isRunning = isGameRunning(gameId: game.id)
                            if isRunning {
                                // 停止游戏
                                await MinecraftLaunchCommand(
                                    player: playerListViewModel.currentPlayer,
                                    game: game,
                                    gameRepository: gameRepository
                                ).stopGame()
                            } else {
                                // 启动游戏（显示加载状态，直到启动流程结束或失败）
                                gameStatusManager.setGameLaunching(gameId: game.id, isLaunching: true)
                                defer { gameStatusManager.setGameLaunching(gameId: game.id, isLaunching: false) }
                                await MinecraftLaunchCommand(
                                    player: playerListViewModel.currentPlayer,
                                    game: game,
                                    gameRepository: gameRepository
                                ).launchGame()
                            }
                        }
                    } label: {
                        let isRunning = isGameRunning(gameId: game.id)
                        let isLaunchingGame = gameStatusManager.isGameLaunching(gameId: game.id)
                        if isLaunchingGame && !isRunning {
                            // 启动中：显示加载指示而不是三角/正方形
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(
                                isRunning
                                ? "stop.fill".localized()
                                : "play.fill".localized(),
                                systemImage: isRunning
                                ? "stop.fill" : "play.fill"
                            )
                        }
                    }
                    .help(
                        isGameRunning(gameId: game.id)
                        ? "stop.fill"
                        : (gameStatusManager.isGameLaunching(gameId: game.id) ? "" : "play.fill")
                    )
                    .disabled(gameStatusManager.isGameLaunching(gameId: game.id)) // 启动过程中禁用按钮，避免重复点击
                    .applyReplaceTransition()

                    Button {
                        gameActionManager.showInFinder(game: game)
                    } label: {
                        Label("game.path".localized(), systemImage: "folder")
                            .foregroundStyle(.primary)
                    }
                    .help("game.path".localized())
                }
            case .resource:
                if selectProjectId != nil {
                    Button {
                        if let id = gameId {
                            selectedItem = .game(id)
                        } else {
                            selectProjectId = nil
                            selectedTab = 0
                        }
                    } label: {
                        Label("return".localized(), systemImage: "arrow.backward")
                    }
                    .help("return".localized())
                } else {
                    if gameType {
                        dataSourceMenu
                    }
                }
            }
        }
    }

    private var currentResourceTitle: String {
        "resource.content.type.\(gameResourcesType)".localized()
    }
    private var currentResourceTypeTitle: String {
        gameType
            ? "resource.content.type.server".localized()
            : "resource.content.type.local".localized()
    }

    private var resourcesMenu: some View {
        Menu {
            ForEach(resourceTypesForCurrentGame, id: \.self) { sort in
                Button("resource.content.type.\(sort)".localized()) {
                    gameResourcesType = sort
                }
            }
        } label: {
            Label(currentResourceTitle, systemImage: "").labelStyle(.titleOnly)
        }.help("resource.content.type.help".localized())
    }

    private var resourcesTypeMenu: some View {
        Button {
            gameType.toggle()
        } label: {
            Label(
                currentResourceTypeTitle,
                systemImage: gameType
                    ? "tray.and.arrow.down" : "icloud.and.arrow.down"
            ).foregroundStyle(.primary)
        }
        .help("resource.content.location.help".localized())
        .applyReplaceTransition()
    }

    private var resourceTypesForCurrentGame: [String] {
        var types = ["datapack", "resourcepack"]
        if let game = currentGame, game.modLoader.lowercased() != "vanilla" {
            types.insert("mod", at: 0)
            types.insert("shader", at: 2)
        }
        return types
    }

    private var dataSourceMenu: some View {
        Menu {
            ForEach(DataSource.allCases, id: \.self) { source in
                Button(source.localizedName) {
                    // 只更新当前选择的值，不影响设置
                    dataSource = source
                }
            }
        } label: {
            // 显示当前选择的值
            Label(dataSource.localizedName, systemImage: "network")
                .labelStyle(.titleOnly)
        }
    }

    /// 本地资源筛选菜单（全部 / 已禁用）
    private var localResourceFilterMenu: some View {
        Menu {
            ForEach(LocalResourceFilter.allCases) { filter in
                Button {
                    localResourceFilter = filter
                } label: {
                    if localResourceFilter == filter {
                        Label(filter.title, systemImage: "checkmark")
                    } else {
                        Text(filter.title)
                    }
                }
            }
        } label: {
            Text(localResourceFilter.title)
        }
    }
}
