import SwiftUI
import Combine

/// 侧边栏：游戏列表与资源列表导航
public struct SidebarView: View {
    @EnvironmentObject var detailState: ResourceDetailState
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var gameLaunchUseCase: GameLaunchUseCase
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @State private var searchText: String = ""
    @State private var showDeleteAlert: Bool = false
    @State private var gameToDelete: GameVersionInfo?
    @State private var gameToExport: GameVersionInfo?
    @StateObject private var gameActionManager = GameActionManager.shared
    @StateObject private var gameStatusManager = GameStatusManager.shared
    @ObservedObject private var selectedGameManager = SelectedGameManager.shared
    @State private var iconRefreshTriggers: [String: UUID] = [:]
    @State private var cancellable: AnyCancellable?

    @Environment(\.openSettings)
    private var openSettings

    public init() {}

    public var body: some View {
        List(selection: detailState.selectedItemOptionalBinding) {
            // 资源部分
            Section(header: Text("sidebar.resources.title".localized())) {
                ForEach(ResourceType.allCases, id: \.self) { type in
                    NavigationLink(value: SidebarItem.resource(type)) {
                        HStack(spacing: 6) {
                            Label(type.localizedName, systemImage: type.systemImage)
                        }
                    }
                }
            }

            // 游戏部分
            Section(header: Text("sidebar.games.title".localized())) {
                ForEach(filteredGames) { game in
                    NavigationLink(value: SidebarItem.game(game.id)) {
                        HStack(spacing: 6) {
                            GameIconView(
                                game: game,
                                refreshTrigger: iconRefreshTriggers[game.gameName] ?? UUID()
                            )
                            Text(game.gameName)
                                .lineLimit(1)
                        }
                        .tag(game.id)
                    }
                    .contextMenu {
                        GameContextMenu(
                            game: game,
                            onDelete: { gameToDelete = game; showDeleteAlert = true },
                            onOpenSettings: { openSettings() },
                            onExport: {
                                gameToExport = game
                            }
                        )
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
        .onAppear {
            // 初始化所有游戏的刷新触发器
            for game in gameRepository.games where iconRefreshTriggers[game.gameName] == nil {
                iconRefreshTriggers[game.gameName] = UUID()
            }
            // 监听图标刷新通知
            cancellable = IconRefreshNotifier.shared.refreshPublisher
                .sink { refreshedGameName in
                    if let gameName = refreshedGameName {
                        // 刷新特定游戏的图标
                        iconRefreshTriggers[gameName] = UUID()
                    } else {
                        // 刷新所有游戏的图标
                        for game in gameRepository.games {
                            iconRefreshTriggers[game.gameName] = UUID()
                        }
                    }
                }
        }
        .onDisappear {
            cancellable?.cancel()
        }
        .onChange(of: gameRepository.games) { _, newGames in
            // 当游戏列表变化时，为新游戏初始化刷新触发器
            for game in newGames where iconRefreshTriggers[game.gameName] == nil {
                iconRefreshTriggers[game.gameName] = UUID()
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
                        selectedItem: detailState.selectedItemBinding,
                        gameType: detailState.gameTypeBinding
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
        .sheet(item: $gameToExport) { game in
            ModPackExportSheet(gameInfo: game)
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
}

// MARK: - Game Icon View

/// 游戏图标视图组件，支持图标刷新
private struct GameIconView: View {
    let game: GameVersionInfo
    let refreshTrigger: UUID

    /// 获取图标URL（添加刷新触发器作为查询参数，强制AsyncImage重新加载）
    private var iconURL: URL {
        let profileDir = AppPaths.profileDirectory(gameName: game.gameName)
        let baseURL = profileDir.appendingPathComponent(game.gameIcon)
        // 添加刷新触发器作为查询参数，确保文件更新后能重新加载
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "refresh", value: refreshTrigger.uuidString)]
        return components?.url ?? baseURL
    }

    var body: some View {
        Group {
            if FileManager.default.fileExists(atPath: profileDir.appendingPathComponent(game.gameIcon).path) {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().controlSize(.mini)
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
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 20, height: 29)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(width: 20, height: 20, alignment: .center)
    }

    private var profileDir: URL {
        AppPaths.profileDirectory(gameName: game.gameName)
    }
}

// MARK: - Game Context Menu

/// 游戏右键菜单组件，优化内存使用
/// 使用独立的视图组件和缓存的状态，减少内存占用
private struct GameContextMenu: View {
    let game: GameVersionInfo
    let onDelete: () -> Void
    let onOpenSettings: () -> Void
    let onExport: () -> Void

    @ObservedObject private var gameStatusManager = GameStatusManager.shared
    @ObservedObject private var gameActionManager = GameActionManager.shared
    @ObservedObject private var selectedGameManager = SelectedGameManager.shared
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var gameLaunchUseCase: GameLaunchUseCase

    /// 使用缓存的游戏状态，避免每次渲染都检查进程
    /// key 为 processKey(gameId, userId)，当前选中的玩家决定 userId
    private var isRunning: Bool {
        let userId = playerListViewModel.currentPlayer?.id ?? ""
        let key = GameProcessManager.processKey(gameId: game.id, userId: userId)
        return gameStatusManager.allGameStates[key] ?? false
    }

    var body: some View {
        Button(action: {
            toggleGameState()
        }, label: {
            Label(
                isRunning ? "stop.fill".localized() : "play.fill".localized(),
                systemImage: isRunning ? "stop.fill" : "play.fill"
            )
        })

        Button(action: {
            gameActionManager.showInFinder(game: game)
        }, label: {
            Label("sidebar.context_menu.show_in_finder".localized(), systemImage: "folder")
        })

        Button(action: {
            selectedGameManager.setSelectedGameAndOpenAdvancedSettings(game.id)
            onOpenSettings()
        }, label: {
            Label("settings.game.advanced.tab".localized(), systemImage: "gearshape")
        })

        Divider()

        Button(action: onExport) {
            Label("modpack.export.button".localized(), systemImage: "square.and.arrow.up")
        }

        Button(action: onDelete) {
            Label("sidebar.context_menu.delete_game".localized(), systemImage: "trash")
        }
    }

    /// 启动或停止游戏
    private func toggleGameState() {
        Task {
            let userId = playerListViewModel.currentPlayer?.id ?? ""
            let key = GameProcessManager.processKey(gameId: game.id, userId: userId)
            let currentlyRunning = gameStatusManager.allGameStates[key] ?? false
            if currentlyRunning {
                await gameLaunchUseCase.stopGame(player: playerListViewModel.currentPlayer, game: game)
            } else {
                gameStatusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: true)
                defer { gameStatusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: false) }
                await gameLaunchUseCase.launchGame(
                    player: playerListViewModel.currentPlayer,
                    game: game
                )
            }
        }
    }
}
