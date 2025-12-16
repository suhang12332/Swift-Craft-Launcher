import SwiftUI

/// 通用侧边栏视图组件，用于显示游戏列表和资源列表的导航
public struct SidebarView: View {
    @Binding var selectedItem: SidebarItem
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @State private var searchText: String = ""
    @State private var showDeleteAlert: Bool = false
    @State private var gameToDelete: GameVersionInfo?
    @StateObject private var gameActionManager = GameActionManager.shared
    @StateObject private var gameStatusManager = GameStatusManager.shared
    @StateObject private var selectedGameManager = SelectedGameManager.shared

    @Environment(\.openSettings)
    private var openSettings

    public init(selectedItem: Binding<SidebarItem>) {
        self._selectedItem = selectedItem
    }

    public var body: some View {
        List(selection: $selectedItem) {
            // 资源部分
            Section(header: Text("sidebar.resources.title".localized())) {
                ForEach(ResourceType.allCases, id: \.self) { type in
                    NavigationLink(value: SidebarItem.resource(type)) {
                        Text(type.localizedName)
                    }
                }
            }

            // 游戏部分
            Section(header: Text("sidebar.games.title".localized())) {
                ForEach(filteredGames) { game in
                    NavigationLink(value: SidebarItem.game(game.id)) {
                        HStack(spacing: 6) {
                            let profileDir = AppPaths.profileDirectory(gameName: game.gameName)
                            let iconURL = profileDir.appendingPathComponent(game.gameIcon)
                            if FileManager.default.fileExists(atPath: iconURL.path) {
                                AsyncImage(url: iconURL) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image
                                        .resizable()
                                        .interpolation(.none)
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    case .failure:
                                    Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                                        .resizable()
                                        .interpolation(.none)
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                                    .resizable()
                                    .interpolation(.none)
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            Text(game.gameName)
                                .lineLimit(1)
                        }
                        .tag(game.id)
                    }
                    .contextMenu {
                        Button(action: {
                            toggleGameState(for: game)
                        }, label: {
                            let isRunning = isGameRunning(gameId: game.id)
                            Label(
                                isRunning ? "stop.fill".localized() : "play.fill".localized(),
                                systemImage: isRunning ? "stop.fill" : "play.fill"
                            )
                        })

                        Button(action: {
                            showInFinder(game: game)
                        }, label: {
                            Label("sidebar.context_menu.show_in_finder".localized(), systemImage: "folder")
                        })

                        Button(action: {
                            // 设置当前游戏并标记应该打开高级设置
                            selectedGameManager.setSelectedGameAndOpenAdvancedSettings(game.id)
                            // 打开设置窗口
                            openSettings()
                        }, label: {
                            Label("settings.game.advanced.tab".localized(), systemImage: "gearshape")
                        })

                        Button(action: {
                            gameToDelete = game
                            showDeleteAlert = true
                        }, label: {
                            Label("sidebar.context_menu.delete_game".localized(), systemImage: "trash")
                        })
                    }
                }
            }
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: Localized.Sidebar.Search.games)
        .safeAreaInset(edge: .bottom) {
            // 显示玩家列表（如有玩家）
            if !playerListViewModel.players.isEmpty {
                PlayerListView()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .listStyle(.sidebar)
        .confirmationDialog(
            "delete.title".localized(),
            isPresented: $showDeleteAlert,
            titleVisibility: .visible
        ) {
            Button("common.delete".localized(), role: .destructive) {
                if let game = gameToDelete {
                    gameActionManager.deleteGame(
                        game: game,
                        gameRepository: gameRepository,
                        selectedItem: $selectedItem
                    )
                }
            }
            .keyboardShortcut(.defaultAction)
            Button("common.cancel".localized(), role: .cancel) {}
        } message: {
            if let game = gameToDelete {
                Text(
                    String(format: "delete.game.confirm".localized(), game.gameName)
                )
            }
        }
    }

    // 只对游戏名做模糊搜索
    private var filteredGames: [GameVersionInfo] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return gameRepository.games
        }
        let lower = searchText.lowercased()
        return gameRepository.games.filter { $0.gameName.lowercased().contains(lower) }
    }

    // MARK: - Game Actions

    /// 检查游戏是否正在运行
    private func isGameRunning(gameId: String) -> Bool {
        return gameStatusManager.isGameRunning(gameId: gameId)
    }

    /// 启动或停止游戏
    private func toggleGameState(for game: GameVersionInfo) {
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
    }

    // MARK: - Context Menu Actions

    /// 在访达中显示游戏目录
    private func showInFinder(game: GameVersionInfo) {
        gameActionManager.showInFinder(game: game)
    }
}
