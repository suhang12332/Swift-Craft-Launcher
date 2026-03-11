import SwiftUI

/// 详情区域工具栏内容
public struct DetailToolbarView: ToolbarContent {
    @Environment(\.openURL)
    private var openURL
    @EnvironmentObject var filterState: ResourceFilterState
    @EnvironmentObject var detailState: ResourceDetailState
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var gameLaunchUseCase: GameLaunchUseCase
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @StateObject private var gameStatusManager = GameStatusManager.shared
    @StateObject private var gameActionManager = GameActionManager.shared
    @State private var showDeleteAlert: Bool = false
    @State private var showExportSheet: Bool = false
    @State private var activeGame: GameVersionInfo?

    private var currentGame: GameVersionInfo? {
        if case .game(let gameId) = detailState.selectedItem {
            return gameRepository.getGame(by: gameId)
        }
        return nil
    }

    private func isGameRunning(gameId: String, userId: String) -> Bool {
        gameStatusManager.isGameRunning(gameId: gameId, userId: userId)
    }

    /// 打开当前资源在浏览器中的项目页面
    private func openCurrentResourceInBrowser() {
        guard let slug = detailState.loadedProjectDetail?.slug else { return }

        let baseURL: String = switch filterState.dataSource {
        case .modrinth:
            URLConfig.API.Modrinth.webProjectBase
        case .curseforge:
            URLConfig.API.CurseForge.webProjectURL(projectType: detailState.gameResourcesType)
        }

        guard let url = URL(string: baseURL + slug) else { return }
        openURL(url)
    }

    private func openInstallSheet() {
        guard let projectId = detailState.selectedProjectId else { return }
        let resourceType = detailState.gameResourcesType

        Task {
            if resourceType == "modpack" {
                guard let detail = await ResourceDetailLoader.loadModPackDetail(
                    projectId: projectId
                ) else {
                    return
                }
                await MainActor.run {
                    applyProjectDetail(
                        detail: detail,
                        projectType: "modpack",
                        versions: [],
                        clientSide: "",
                        serverSide: ""
                    )
                }
            } else {
                guard let result = await ResourceDetailLoader.loadProjectDetail(
                    projectId: projectId,
                    gameRepository: gameRepository,
                    resourceType: resourceType
                ) else {
                    return
                }
                await MainActor.run {
                    applyProjectDetail(
                        detail: result.detail,
                        compatibleGames: result.compatibleGames,
                        projectType: result.detail.projectType,
                        versions: result.detail.versions,
                        clientSide: result.detail.clientSide,
                        serverSide: result.detail.serverSide
                    )
                }
            }
        }
    }

    private func applyProjectDetail(
        detail: ModrinthProjectDetail,
        compatibleGames: [GameVersionInfo]? = nil,
        projectType: String,
        versions: [String],
        clientSide: String,
        serverSide: String
    ) {
        detailState.currentProject = ModrinthProject(
            projectId: detail.id,
            projectType: projectType,
            slug: detail.slug,
            author: "",
            title: detail.title,
            description: detail.description,
            categories: detail.categories,
            displayCategories: [],
            versions: versions,
            downloads: detail.downloads,
            follows: detail.followers,
            iconUrl: detail.iconUrl,
            license: detail.license?.url ?? "",
            clientSide: clientSide,
            serverSide: serverSide,
            fileName: nil
        )
        detailState.loadedProjectDetail = detail
        if let compatibleGames {
            detailState.compatibleGames = compatibleGames
        }
        detailState.showInstallSheet = true
    }

    public var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            switch detailState.selectedItem {
            case .game:
                if let game = currentGame {
                    resourcesTypeMenu
                    resourcesMenu
                    if !detailState.gameType {
                        localResourceFilterMenu
                    }
                    if detailState.gameType {
                        dataSourceMenu
                    }

                    Spacer()

                    Button {
                        Task {
                            let userId = playerListViewModel.currentPlayer?.id ?? ""
                            let isRunning = isGameRunning(gameId: game.id, userId: userId)
                            if isRunning {
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
                    } label: {
                        let userId = playerListViewModel.currentPlayer?.id ?? ""
                        let isRunning = isGameRunning(gameId: game.id, userId: userId)
                        let isLaunchingGame = gameStatusManager.isGameLaunching(gameId: game.id, userId: userId)
                        if isLaunchingGame && !isRunning {
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
                        isGameRunning(gameId: game.id, userId: playerListViewModel.currentPlayer?.id ?? "")
                        ? "stop.fill"
                        : (gameStatusManager.isGameLaunching(gameId: game.id, userId: playerListViewModel.currentPlayer?.id ?? "") ? "" : "play.fill")
                    )
                    .disabled(gameStatusManager.isGameLaunching(gameId: game.id, userId: playerListViewModel.currentPlayer?.id ?? ""))
                    .applyReplaceTransition()

                    Button {
                        gameActionManager.showInFinder(game: game)
                    } label: {
                        Label("game.path".localized(), systemImage: "folder")
                    }
                    .help("game.path".localized())

                    Button {
                        activeGame = game
                        showExportSheet = true
                    } label: {
                        Label("modpack.export.button".localized(), systemImage: "square.and.arrow.up")
                    }
                    .help("modpack.export.button".localized())
                    .sheet(isPresented: $showExportSheet) {
                        if let exportGame = activeGame {
                            ModPackExportSheet(gameInfo: exportGame)
                        }
                    }

                    Button(role: .destructive) {
                        activeGame = game
                        showDeleteAlert = true
                    } label: {
                        Label("sidebar.context_menu.delete_game".localized(), systemImage: "trash")
                    }
                    .help("sidebar.context_menu.delete_game".localized())
                    .confirmationDialog(
                        "delete.title".localized(),
                        isPresented: $showDeleteAlert,
                        titleVisibility: .visible
                    ) {
                        Button("common.delete".localized(), role: .destructive) {
                            if let deletingGame = activeGame {
                                gameActionManager.deleteGame(
                                    game: deletingGame,
                                    gameRepository: gameRepository,
                                    selectedItem: detailState.selectedItemBinding,
                                    gameType: detailState.gameTypeBinding
                                )
                            }
                        }
                        .keyboardShortcut(.defaultAction)
                        Button("common.cancel".localized(), role: .cancel) {}
                    } message: {
                        if let deletingGame = activeGame {
                            Text(
                                String(format: "delete.game.confirm".localized(), deletingGame.gameName)
                            )
                        }
                    }
                }
            case .resource:
                if detailState.selectedProjectId != nil {
                    Button {
                        if let id = detailState.gameId {
                            detailState.selectedItem = .game(id)
                        } else {
                            detailState.selectedProjectId = nil
                            filterState.selectedTab = 0
                        }
                    } label: {
                        Label("return".localized(), systemImage: "arrow.backward")
                    }
                    .help("return".localized())
                    Spacer()
                    Button {
                        openInstallSheet()
                    } label: {
                        Label("resource.add".localized(), systemImage: "arrow.down.circle")
                    }
                    .help("resource.add".localized())
                    .sheet(isPresented: detailState.showInstallSheetBinding) {
                        if let project = detailState.currentProject,
                            let detail = detailState.loadedProjectDetail {
                            if detailState.gameResourcesType == "modpack" {
                                ModPackDownloadSheet(
                                    projectId: project.projectId,
                                    gameInfo: nil,
                                    query: detailState.gameResourcesType,
                                    preloadedDetail: detail
                                )
                                .environmentObject(gameRepository)
                            } else {
                                GlobalResourceSheet(
                                    project: project,
                                    resourceType: detailState.gameResourcesType,
                                    isPresented: detailState.showInstallSheetBinding,
                                    preloadedDetail: detail,
                                    preloadedCompatibleGames: detailState.compatibleGames
                                )
                                .environmentObject(gameRepository)
                            }
                        }
                    }
                    .onChange(of: detailState.showInstallSheet) { _, newValue in
                        if !newValue {
                            detailState.compatibleGames = []
                        }
                    }
                    Button {
                        openCurrentResourceInBrowser()
                    } label: {
                        Label("common.browser".localized(), systemImage: "safari")
                    }
                    .help("resource.open_in_browser".localized())
                } else {
                    if detailState.gameType {
                        dataSourceMenu
                    }
                }
            }
        }
    }

    private var currentResourceTitle: String {
        "resource.content.type.\(detailState.gameResourcesType)".localized()
    }
    private var currentResourceTypeTitle: String {
        detailState.gameType
            ? "resource.content.type.server".localized()
            : "resource.content.type.local".localized()
    }

    private var resourcesMenu: some View {
        Menu {
            ForEach(resourceTypesForCurrentGame, id: \.self) { sort in
                Button("resource.content.type.\(sort)".localized()) {
                    detailState.gameResourcesType = sort
                }
            }
        } label: {
            Label(currentResourceTitle, systemImage: "").labelStyle(.titleOnly)
        }.help("resource.content.type.help".localized())
    }

    private var resourcesTypeMenu: some View {
        Button {
            detailState.gameType.toggle()
        } label: {
            Label(
                currentResourceTypeTitle,
                systemImage: detailState.gameType
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
                    filterState.dataSource = source
                }
            }
        } label: {
            Text(filterState.dataSource.localizedName)
        }
    }

    private var localResourceFilterMenu: some View {
        Menu {
            ForEach(LocalResourceFilter.allCases) { filter in
                Button {
                    filterState.localResourceFilter = filter
                } label: {
                    if filterState.localResourceFilter == filter {
                        Label(filter.title, systemImage: "checkmark")
                    } else {
                        Text(filter.title)
                    }
                }
            }
        } label: {
            Text(filterState.localResourceFilter.title)
        }
    }
}
