import SwiftUI

/// 通用侧边栏视图组件，用于显示游戏列表和资源列表的导航
public struct SidebarView: View {
    @Binding var selectedItem: SidebarItem
    @Binding var gameType: Bool
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @State private var searchText: String = ""
    @State private var searchDebounceTask: Task<Void, Never>?
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

    // 缓存的显示游戏列表，避免重复计算
    @State private var displayedGames: [GameVersionInfo] = []

    // 预加载状态
    @State private var hasPreloadedIcons: Bool = false
    @State private var preloadTask: Task<Void, Never>?

    @Environment(\.openSettings)
    private var openSettings

    public init(selectedItem: Binding<SidebarItem>, gameType: Binding<Bool> = .constant(true)) {
        self._selectedItem = selectedItem
        self._gameType = gameType
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
                        selectedItem: $selectedItem,
                        gameType: $gameType
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
            // 取消上一次尚未执行的搜索任务
            searchDebounceTask?.cancel()

            // 启动新的 debounce 任务（150ms）
            searchDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    updateFilteredGames()
                }
            }
        }
        // 只监听实际需要的变化
        .onChange(of: gameRepository.games) { old, new in
            // 只有当游戏列表本身变化时才重新过滤
            // 使用 Set 比较而不是数组比较，性能更好
            let oldIds = Set(old.map(\.id))
            let newIds = Set(new.map(\.id))
            if oldIds != newIds {
                updateFilteredGames()
            }
        }
        .onAppear {
            updateFilteredGames()
            preloadGameIcons()
        }
        .onDisappear {
            // 取消预加载任务，避免资源浪费
            preloadTask?.cancel()
            preloadTask = nil
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
        GeometryReader { _ in
            List(selection: $selectedItem) {
                Section(header: Text("sidebar.games.title".localized())) {
                    ForEach(displayedGames.indices, id: \.self) { index in
                        let game = displayedGames[index]
                        NavigationLink(value: SidebarItem.game(game.id)) {
                            HStack(spacing: 6) {
                                // 使用优化的 GameIconView 组件，避免重复的文件系统 I/O
                                // 使用稳定的 id 避免视图重新创建
                                GameIconView(
                                    gameName: game.gameName,
                                    iconName: game.gameIcon,
                                    size: 16
                                )
                                .id("\(game.id)-\(game.gameIcon)")
                                Text(game.gameName)
                                    .lineLimit(1)
                            }
                        }
                        .onAppear {
                            // 仅在接近底部的 item 触发分页判断，避免每行都参与
                            if index >= displayedGameCount - Self.loadMoreThreshold {
                                checkAndLoadMoreIfNeeded(at: index)
                            }
                        }
                        .modifier(
                            ConditionalContextMenu(
                                isEnabled: selectedItem == .game(game.id)
                            ) {
                                gameContextMenu(for: game)
                            }
                        )
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(maxHeight: .infinity)
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
        updateDisplayedGames()
    }

    // MARK: - Pagination

    /// 更新显示的游戏列表（分页加载）
    /// 避免在计算属性中重复创建数组
    private func updateDisplayedGames() {
        let count = min(displayedGameCount, cachedFilteredGames.count)
        displayedGames = Array(cachedFilteredGames.prefix(count))
    }

    /// 检查是否需要加载更多游戏
    /// 当滚动到接近列表底部时自动加载更多
    private func checkAndLoadMoreIfNeeded(at index: Int) {
        let remainingCount = cachedFilteredGames.count - index - 1

        if remainingCount <= Self.loadMoreThreshold &&
           displayedGameCount < cachedFilteredGames.count {

            Task { @MainActor in
                displayedGameCount = min(
                    displayedGameCount + Self.initialLoadCount,
                    cachedFilteredGames.count
                )
                updateDisplayedGames()
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

        // 取消之前的预加载任务（如果存在）
        preloadTask?.cancel()

        preloadTask = Task {
            let iconCache = GameIconCache.shared
            // 预加载前 10 个游戏的图标信息（在后台线程执行）
            // 使用当前缓存的过滤结果，避免捕获过时的数据
            let gamesToPreload = Array(cachedFilteredGames.prefix(10))

            await Task.detached(priority: .utility) {
                for game in gamesToPreload {
                    // 检查任务是否已取消
                    guard !Task.isCancelled else { break }

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

    @ViewBuilder
    private func gameContextMenu(for game: GameVersionInfo) -> some View {
        Button {
            toggleGameState(for: game)
        } label: {
            let isRunning = isGameRunning(gameId: game.id)
            Label(
                isRunning ? "stop.fill".localized() : "play.fill".localized(),
                systemImage: isRunning ? "stop.fill" : "play.fill"
            )
        }

        Button {
            showInFinder(game: game)
        } label: {
            Label("sidebar.context_menu.show_in_finder".localized(), systemImage: "folder")
        }

        Button {
            selectedGameManager.setSelectedGameAndOpenAdvancedSettings(game.id)
            openSettings()
        } label: {
            Label("settings.game.advanced.tab".localized(), systemImage: "gearshape")
        }

        Button {
            gameToDelete = game
            showDeleteAlert = true
        } label: {
            Label("sidebar.context_menu.delete_game".localized(), systemImage: "trash")
        }
    }

    // MARK: - Conditional Context Menu (macOS Performance)

    private struct ConditionalContextMenu<MenuContent: View>: ViewModifier {
        let isEnabled: Bool
        let menuContent: () -> MenuContent

        func body(content: Content) -> some View {
            if isEnabled {
                content.contextMenu {
                    menuContent()
                }
            } else {
                content
            }
        }
    }
}
