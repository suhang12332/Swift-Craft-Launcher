import SwiftUI

/// 详情区域工具栏内容
public struct DetailToolbarView: ToolbarContent {
    @Binding var selectedItem: SidebarItem
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @Binding var sortIndex: String
    @Binding var gameResourcesType: String
    @Binding var gameType: Bool  // false = local, true = server
    @Binding var currentPage: Int
    @Binding var versionCurrentPage: Int
    @Binding var versionTotal: Int
    @EnvironmentObject var gameRepository: GameRepository
    @StateObject private var gameStatusManager = GameStatusManager.shared
    let totalItems: Int
    @Binding var project: ModrinthProjectDetail?
    @Binding var selectProjectId: String?
    @Binding var selectedTab: Int
    @Binding var gameId: String?

    // MARK: - Computed Properties
    var totalPages: Int {
        max(1, Int(ceil(Double(totalItems) / Double(20))))
    }

    private func handlePageChange(_ increment: Int) {
        let newPage = currentPage + increment
        if newPage >= 1 && newPage <= totalPages {
            currentPage = newPage
        }
    }

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
                        sortMenu
                        paginationControls
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
                        return Label(
                            isRunning
                                ? "stop.fill".localized()
                                : "play.fill".localized(),
                            systemImage: isRunning
                                ? "stop.fill" : "play.fill"
                        )
                    }
                    .help(
                        (isGameRunning(gameId: game.id) ? "stop.fill" : "play.fill").localized()
                    )
                    .contentTransition(.symbolEffect(.replace.offUp.byLayer, options: .nonRepeating))

                    Button {
                        let gameDir = AppPaths.profileDirectory(gameName: game.gameName)
                        if FileManager.default.fileExists(atPath: gameDir.path) {
                            NSWorkspace.shared.selectFile(
                                nil,
                                inFileViewerRootedAtPath: gameDir.path
                            )
                        }
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
                        selectedTab: $selectedTab,
                        versionCurrentPage: $versionCurrentPage,
                        versionTotal: $versionTotal,
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
                    sortMenu
                    paginationControls
                    Spacer()
                }
            }
        }
    }

    private var currentSortTitle: String {
        "menu.sort.\(sortIndex)".localized()
    }
    private var currentResourceTitle: String {
        "resource.content.type.\(gameResourcesType)".localized()
    }
    private var currentResourceTypeTitle: String {
        gameType
            ? "resource.content.type.server".localized()
            : "resource.content.type.local".localized()
    }

    private var sortMenu: some View {
        Menu {
            ForEach(
                ["relevance", "downloads", "follows", "newest", "updated"],
                id: \.self
            ) { sort in
                Button("menu.sort.\(sort)".localized()) {
                    sortIndex = sort
                    currentPage = 1
                }
            }
        } label: {
            Label(currentSortTitle, systemImage: "").labelStyle(.titleOnly)
        }.help("menu.sort.help".localized())
    }

    private var resourcesMenu: some View {
        Menu {
            ForEach(resourceTypesForCurrentGame, id: \.self) { sort in
                Button("resource.content.type.\(sort)".localized()) {
                    gameResourcesType = sort
                    currentPage = 1
                }
            }
        } label: {
            Label(currentResourceTitle, systemImage: "").labelStyle(.titleOnly)
        }.help("resource.content.type.help".localized())
    }

    private var resourcesTypeMenu: some View {
        Button {
            gameType.toggle()
            currentPage = 1
        } label: {
            Label(
                currentResourceTypeTitle,
                systemImage: gameType
                    ? "tray.and.arrow.down" : "icloud.and.arrow.down"
            ).foregroundStyle(.primary)
        }
        .help("resource.content.location.help".localized())
        .contentTransition(.symbolEffect(.replace.offUp.byLayer, options: .nonRepeating))
    }

    private var paginationControls: some View {
        HStack(spacing: 8) {
            Button {
                handlePageChange(-1)
            } label: {
                Label(
                    "pagination.help".localized(),
                    systemImage: "chevron.left"
                )
            }
            .disabled(currentPage == 1)

            HStack(spacing: 8) {
                Text(
                    String(
                        format: "pagination.current".localized(),
                        currentPage
                    )
                )
                Divider().frame(height: 16)
                Text(String(format: "pagination.total".localized(), totalPages))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            Button {
                handlePageChange(1)
            } label: {
                Label(
                    "pagination.help".localized(),
                    systemImage: "chevron.right"
                )
            }
            .disabled(currentPage == totalPages)
        }
        .help("pagination.help".localized())
    }

    private var resourceTypesForCurrentGame: [String] {
        var types = ["datapack", "resourcepack"]
        if let game = currentGame, game.modLoader.lowercased() != "vanilla" {
            types.insert("mod", at: 0)
            types.insert("shader", at: 2)
        }
        return types
    }
}
