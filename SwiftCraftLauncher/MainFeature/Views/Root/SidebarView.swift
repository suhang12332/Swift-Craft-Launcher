import SwiftUI

/// 侧边栏：游戏列表与资源列表导航
public struct SidebarView: View {
    @EnvironmentObject var detailState: ResourceDetailState
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var gameLaunchUseCase: GameLaunchUseCase
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @State private var searchText: String = ""
    @ObservedObject private var gameDialogsPresenter = GameDialogsPresenter.shared
    @StateObject private var gameActionManager = GameActionManager.shared
    @StateObject private var gameStatusManager = GameStatusManager.shared
    @ObservedObject private var selectedGameManager = SelectedGameManager.shared
    @StateObject private var viewModel = SidebarViewModel()

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
                                refreshTrigger: viewModel.refreshTrigger(for: game.gameName)
                            )
                            Text(game.gameName)
                                .lineLimit(1)
                        }
                        .tag(game.id)
                    }
                    .contextMenu {
                        GameContextMenu(
                            game: game,
                            onDelete: { gameDialogsPresenter.requestGameDeletion(of: game) },
                            onOpenSettings: { openSettings() },
                            onExport: {
                                gameDialogsPresenter.presentModPackExport(for: game)
                            }
                        )
                    }
                }
            }

            // 损坏游戏部分（数据库和文件夹不一致）
            if !filteredCorruptedGames.isEmpty {
                Section(header: Text("sidebar.corrupted_games.title".localized())) {
                    ForEach(filteredCorruptedGames, id: \.self) { name in
                        HStack(spacing: 6) {
                            Label(name, systemImage: "exclamationmark.triangle")
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                gameActionManager.deleteCorruptedGame(
                                    name: name,
                                    gameRepository: gameRepository
                                )
                            } label: {
                                Label("sidebar.context_menu.delete_game".localized(), systemImage: "trash")
                            }
                        }
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
            viewModel.onAppear(games: gameRepository.games)
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: gameRepository.games) { _, newGames in
            // 当游戏列表变化时，为新游戏初始化刷新触发器
            viewModel.onGamesChanged(newGames)
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

    /// 损坏游戏名称的模糊搜索
    private var filteredCorruptedGames: [String] {
        let names = gameRepository.corruptedGames
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return names
        }
        let lower = trimmed.lowercased()
        return names.filter { $0.lowercased().contains(lower) }
    }
}
