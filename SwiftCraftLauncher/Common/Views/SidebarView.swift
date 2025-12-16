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
    @ObservedObject private var selectedGameManager = SelectedGameManager.shared

    // 缓存的过滤结果，避免重复计算
    @State private var cachedFilteredGames: [GameVersionInfo] = []
    @State private var lastSearchText: String = ""
    @State private var lastGamesCount: Int = 0

    // 分页加载配置
    private static let initialLoadCount = 30  // 初始加载的游戏数量
    private static let loadMoreThreshold = 10  // 距离底部多少项时开始加载更多
    @State private var displayedGameCount: Int = Self.initialLoadCount

    // 预加载状态
    @State private var hasPreloadedIcons: Bool = false

    @Environment(\.openSettings)
    private var openSettings

    public init(selectedItem: Binding<SidebarItem>) {
        self._selectedItem = selectedItem
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 资源部分（固定）
            resourcesSection
                .searchable(text: $searchText, placement: .sidebar, prompt: Localized.Sidebar.Search.games)
            // 游戏部分（可滚动）
            gamesSection
        }

        .safeAreaInset(edge: .bottom) {
            // 显示玩家列表（如有玩家）
            if !playerListViewModel.players.isEmpty {
                PlayerListView()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
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
        .onChange(of: searchText) { _, _ in
            updateFilteredGames()
        }
        .onChange(of: gameRepository.games.count) { _, _ in
            updateFilteredGames()
        }
        .onAppear {
            updateFilteredGames()
            preloadGameIcons()
        }
    }

    // MARK: - View Components

    /// 资源部分（固定）
    private var resourcesSection: some View {
        List(selection: $selectedItem) {
            Section(header: Text("sidebar.resources.title".localized())) {
                ForEach(ResourceType.allCases, id: \.self) { type in
                    NavigationLink(value: SidebarItem.resource(type)) {
                        Text(type.localizedName)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(height: CGFloat(ResourceType.allCases.count * 24 + 93)) // 固定高度
    }

    /// 游戏部分（可滚动）
    private var gamesSection: some View {
        GeometryReader { geometry in
            List(selection: $selectedItem) {
                Section(header: Text("sidebar.games.title".localized())) {
                    ForEach(displayedGames) { game in
                        NavigationLink(value: SidebarItem.game(game.id)) {
                            HStack(spacing: 6) {
                                // 使用优化的 GameIconView 组件，避免重复的文件系统 I/O
                                GameIconView(
                                    gameName: game.gameName,
                                    iconName: game.gameIcon,
                                    size: 16
                                )
                                Text(game.gameName)
                                    .lineLimit(1)
                            }
                        }
                        .onAppear {
                            checkAndLoadMoreIfNeeded(for: game)
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
            .listStyle(.sidebar)
            .frame(height: geometry.size.height)
        }
    }

    // MARK: - Filtered Games Cache

    /// 更新缓存的过滤结果
    /// 只在搜索文本或游戏列表变化时重新计算
    private func updateFilteredGames() {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentGamesCount = gameRepository.games.count

        // 如果搜索文本和游戏数量都没有变化，使用缓存
        if trimmedSearchText == lastSearchText && currentGamesCount == lastGamesCount {
            return
        }

        // 更新缓存
        lastSearchText = trimmedSearchText
        lastGamesCount = currentGamesCount

        // 计算过滤结果
        if trimmedSearchText.isEmpty {
            cachedFilteredGames = gameRepository.games
        } else {
            let lower = trimmedSearchText.lowercased()
            cachedFilteredGames = gameRepository.games.filter {
                $0.gameName.lowercased().contains(lower)
            }
        }

        // 重置分页加载计数（搜索或列表变化时）
        displayedGameCount = Self.initialLoadCount
    }

    // MARK: - Pagination

    /// 当前显示的游戏列表（分页加载）
    private var displayedGames: [GameVersionInfo] {
        let count = min(displayedGameCount, cachedFilteredGames.count)
        return Array(cachedFilteredGames.prefix(count))
    }

    /// 检查是否需要加载更多游戏
    /// 当滚动到接近列表底部时自动加载更多
    private func checkAndLoadMoreIfNeeded(for game: GameVersionInfo) {
        guard let index = cachedFilteredGames.firstIndex(where: { $0.id == game.id }) else { return }

        // 如果当前游戏距离列表末尾少于阈值，加载更多
        let remainingCount = cachedFilteredGames.count - index - 1
        if remainingCount <= Self.loadMoreThreshold && displayedGameCount < cachedFilteredGames.count {
            Task { @MainActor in
                displayedGameCount = min(displayedGameCount + Self.initialLoadCount, cachedFilteredGames.count)
            }
        }
    }

    // MARK: - Icon Preloading

    /// 预加载前几个游戏的图标信息
    /// 在视图出现时异步预加载，优化初始渲染性能
    private func preloadGameIcons() {
        // 避免重复预加载
        guard !hasPreloadedIcons else { return }
        hasPreloadedIcons = true

        Task {
            let iconCache = GameIconCache.shared
            // 预加载前 10 个游戏的图标信息（在后台线程执行）
            let gamesToPreload = Array(cachedFilteredGames.prefix(10))

            await Task.detached(priority: .utility) {
                for game in gamesToPreload {
                    // 预加载 URL（使用缓存）
                    _ = iconCache.iconURL(gameName: game.gameName, iconName: game.gameIcon)
                    // 预加载文件存在性检查（异步，不阻塞）
                    _ = await iconCache.iconExistsAsync(gameName: game.gameName, iconName: game.gameIcon)
                }
            }.value
        }
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
