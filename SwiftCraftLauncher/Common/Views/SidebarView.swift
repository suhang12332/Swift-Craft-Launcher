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

    // 延迟过滤：只存储游戏ID列表，按需获取完整信息
    @State private var filteredGameIds: [String] = []
    @State private var cachedSearchText: String = ""

    // 延迟加载配置
    private static let initialLoadCount = 20  // 初始加载的游戏数量（减少初始加载）
    private static let loadMoreCount = 20  // 每次加载更多时的数量
    private static let loadMoreThreshold = 5  // 距离底部多少项时开始加载更多（提前加载）
    @State private var displayedGameCount: Int = Self.initialLoadCount
    @State private var isLoadingMore: Bool = false  // 防止重复加载

    // 缓存图标 URL 和文件存在性，避免重复的文件系统访问
    private static let iconCache = NSCache<NSString, NSNumber>()
    private static let iconURLCache = NSCache<NSString, NSURL>()

    // 延迟加载的图标存在性检查（只在可见时检查）
    @State private var checkedIconGames: Set<String> = []

    // 异步图标加载状态（游戏ID -> 是否已加载）
    @State private var loadedIcons: Set<String> = []

    @Environment(\.openSettings)
    private var openSettings

    public init(selectedItem: Binding<SidebarItem>) {
        self._selectedItem = selectedItem
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 资源部分（固定，不滚动）
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
            .scrollDisabled(true) // 禁用滚动
            .frame(height: CGFloat(ResourceType.allCases.count) * 24 + 93) // 根据资源数量动态调整高度（每项约24px，header约30px）
            .searchable(text: $searchText, placement: .sidebar, prompt: Localized.Sidebar.Search.games)
            // 游戏部分（可滚动）
            List(selection: $selectedItem) {
                Section(header: Text("sidebar.games.title".localized())) {
                    ForEach(displayedGames) { game in
                        NavigationLink(value: SidebarItem.game(game.id)) {
                            HStack(spacing: 6) {
                                gameIconView(for: game, isVisible: true)
                                Text(game.gameName)
                                    .lineLimit(1)
                            }
                            .tag(game.id)
                        }
                        .onAppear {
                            // 当游戏项出现时，检查是否需要加载更多
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
            .frame(maxHeight: .infinity) // 占用剩余空间
        }

        .onChange(of: searchText) { _, _ in
            updateFilteredGames()
        }
        .onChange(of: gameRepository.games) { _, _ in
            updateFilteredGames()
        }
        .onAppear {
            updateFilteredGames()
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
    }

    // 当前显示的游戏列表（分页加载，只加载需要显示的游戏）
    private var displayedGames: [GameVersionInfo] {
        // 只处理需要显示的游戏ID
        let displayedIds = Array(filteredGameIds.prefix(displayedGameCount))
        // 按需查找游戏对象，避免处理所有游戏
        let gamesDict = Dictionary(uniqueKeysWithValues: gameRepository.games.map { ($0.id, $0) })
        return displayedIds.compactMap { gamesDict[$0] }
    }

    // 更新过滤后的游戏列表（只存储ID，延迟加载完整数据）
    private func updateFilteredGames() {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        // 如果搜索文本没有变化，且游戏列表没有变化，则不需要重新计算
        if trimmedSearch == cachedSearchText && gameRepository.games.count == filteredGameIds.count {
            return
        }

        cachedSearchText = trimmedSearch

        // 只存储游戏ID，不存储完整的游戏对象，减少内存占用
        if trimmedSearch.isEmpty {
            // 无搜索条件时，只存储ID列表
            filteredGameIds = gameRepository.games.map { $0.id }
        } else {
            // 有搜索条件时，只过滤ID
            let lower = trimmedSearch.lowercased()
            filteredGameIds = gameRepository.games
                .filter { $0.gameName.lowercased().contains(lower) }
                .map { $0.id }
        }

        // 重置显示数量和加载状态，因为过滤结果可能变化
        displayedGameCount = Self.initialLoadCount
        isLoadingMore = false
        // 注意：不清空 loadedIcons，因为图标缓存仍然有效，可以复用
    }

    // 检查是否需要加载更多游戏（优化版本，防止重复加载）
    private func checkAndLoadMoreIfNeeded(for game: GameVersionInfo) {
        // 如果正在加载中，跳过
        guard !isLoadingMore else { return }

        // 直接使用ID列表查找，避免创建完整的游戏对象数组
        guard let index = filteredGameIds.firstIndex(where: { $0 == game.id }) else { return }

        // 如果当前游戏距离列表末尾少于阈值，加载更多
        let remainingCount = filteredGameIds.count - index - 1
        if remainingCount <= Self.loadMoreThreshold && displayedGameCount < filteredGameIds.count {
            // 标记为加载中，防止重复触发
            isLoadingMore = true

            // 延迟加载，避免阻塞 UI
            Task { @MainActor in
                // 使用较小的增量加载，避免一次性加载太多
                displayedGameCount = min(displayedGameCount + Self.loadMoreCount, filteredGameIds.count)
                isLoadingMore = false
            }
        }
    }

    // MARK: - Icon Helpers

    /// 获取游戏图标的 URL（带缓存）
    private func iconURL(for game: GameVersionInfo) -> URL {
        let cacheKey = "\(game.gameName)/\(game.gameIcon)" as NSString

        if let cachedURL = Self.iconURLCache.object(forKey: cacheKey) {
            return cachedURL as URL
        }

        let profileDir = AppPaths.profileDirectory(gameName: game.gameName)
        let iconURL = profileDir.appendingPathComponent(game.gameIcon)
        Self.iconURLCache.setObject(iconURL as NSURL, forKey: cacheKey)
        return iconURL
    }

    /// 检查图标文件是否存在（带缓存，同时缓存 URL）
    private func iconExists(for game: GameVersionInfo) -> Bool {
        let cacheKey = "\(game.gameName)/\(game.gameIcon)" as NSString

        // 如果缓存中有结果，直接返回
        if let cached = Self.iconCache.object(forKey: cacheKey) {
            return cached.boolValue
        }

        // 如果图标尚未异步加载，返回 false（显示默认图标）
        // 实际检查将在异步加载中完成
        return false
    }

    /// 异步加载图标信息
    private func loadIconAsync(for game: GameVersionInfo) async {
        // 避免重复加载
        guard !loadedIcons.contains(game.id) else { return }

        // 标记为正在加载
        await MainActor.run {
            _ = loadedIcons.insert(game.id)
        }

        // 在后台线程检查文件存在性
        // 注意：NSCache 是线程安全的，可以在不同线程访问
        await Task.detached(priority: .utility) {
            // 使用 String 类型，因为它是 Sendable 的
            let cacheKeyString = "\(game.gameName)/\(game.gameIcon)"

            // 在主线程检查缓存（NSCache 是线程安全的，但为了一致性，我们在主线程访问）
            let cachedValue = await MainActor.run {
                let cacheKey = cacheKeyString as NSString
                return Self.iconCache.object(forKey: cacheKey)
            }
            if cachedValue != nil {
                return
            }

            // 获取 URL
            let profileDir = AppPaths.profileDirectory(gameName: game.gameName)
            let iconURL = profileDir.appendingPathComponent(game.gameIcon)

            // 检查文件是否存在（在后台线程执行，避免阻塞 UI）
            let exists = FileManager.default.fileExists(atPath: iconURL.path)

            // 在主线程更新缓存
            await MainActor.run {
                let cacheKey = cacheKeyString as NSString
                Self.iconURLCache.setObject(iconURL as NSURL, forKey: cacheKey)
                Self.iconCache.setObject(NSNumber(value: exists), forKey: cacheKey)
            }
        }.value
    }

    /// 游戏图标视图（优化版本，支持延迟加载）
    @ViewBuilder
    private func gameIconView(for game: GameVersionInfo, isVisible: Bool) -> some View {
        // 延迟加载：只在游戏项可见时才检查图标
        if isVisible && loadedIcons.contains(game.id) {
            // 图标已加载，检查是否存在
            if iconExists(for: game) {
                // 从缓存获取 URL（不会重复计算）
                let url = iconURL(for: game)
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 16, height: 16)
                    case .success(let image):
                        image
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    case .failure:
                        defaultIconView
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                defaultIconView
            }
        } else {
            // 图标未加载或不可见，显示默认图标
            // 如果可见但未加载，触发异步加载
            if isVisible && !loadedIcons.contains(game.id) {
                defaultIconView
                    .onAppear {
                        Task { @MainActor in
                            await loadIconAsync(for: game)
                        }
                    }
            } else {
                defaultIconView
            }
        }
    }

    /// 默认图标视图
    private var defaultIconView: some View {
        Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: 16, height: 16)
            .clipShape(RoundedRectangle(cornerRadius: 4))
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
