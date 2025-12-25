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
                    //                    if !gameType {
                    //                        if let iconURL = AppPaths.profileDirectory(
                    //                            gameName: game.gameName
                    //                        )?.appendingPathComponent(game.gameIcon),
                    //                            FileManager.default.fileExists(atPath: iconURL.path)
                    //                        {
                    //                            AsyncImage(url: iconURL) { phase in
                    //                                switch phase {
                    //                                case .empty:
                    //                                    ProgressView()
                    //                                case .success(let image):
                    //                                    image
                    //                                        .resizable()
                    //                                        .interpolation(.none)
                    //                                        .frame(width: 22, height: 22)
                    //                                        .cornerRadius(6)
                    //                                case .failure:
                    //                                    Image("default_game_icon")
                    //                                        .resizable()
                    //                                        .interpolation(.none)
                    //                                        .frame(width: 22, height: 22)
                    //                                        .cornerRadius(6)
                    //                                @unknown default:
                    //                                    EmptyView()
                    //                                }
                    //                            }
                    //                        } else {
                    //                            Image("default_game_icon")
                    //                                .resizable()
                    //                                .interpolation(.none)
                    //                                .frame(width: 22, height: 22)
                    //                                .cornerRadius(6)
                    //                        }
                    //                        Text(game.gameName)
                    //                            .font(.headline)
                    //                        Spacer()
                    //                    }
                    resourcesTypeMenu
                    resourcesMenu
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
                                // 启动游戏
                                await MinecraftLaunchCommand(
                                    player: playerListViewModel.currentPlayer,
                                    game: game,
                                    gameRepository: gameRepository
                                ).launchGame()
                            }
                        }
                    } label: {
                        let isRunning = isGameRunning(gameId: game.id)
                        let isLaunching = gameStatusManager.isGameLaunching(gameId: game.id)

                        if isLaunching {
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
                        gameStatusManager.isGameLaunching(gameId: game.id)
                            ? ""
                            : (isGameRunning(gameId: game.id) ? "stop.fill" : "play.fill").localized()
                    )
                    .disabled(gameStatusManager.isGameLaunching(gameId: game.id))
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
                    ModrinthProjectDetailToolbarView(
                        projectDetail: project,
                        gameId: gameId
                    ) {
                        if let id = gameId {
                            selectedItem = .game(id)
                        } else {
                            selectProjectId = nil
                            selectedTab = 0
                        }
                    }
                } else {
                    if gameType {
                        dataSourceMenu
                    }
                    Spacer()
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
}
