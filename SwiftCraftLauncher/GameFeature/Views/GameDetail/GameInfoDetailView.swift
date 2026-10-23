//
//  GameInfoDetailView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// Displays game information details with local and remote resource browsing.
import SwiftUI
import UniformTypeIdentifiers

struct GameInfoDetailView: View {
    @Environment(DIContainer.self)
    private var container
    let game: GameVersionInfo

    let query: String
    let dataSource: DataSource
    let selectedVersions: [String]
    let selectedCategories: [String]
    let selectedFeatures: [String]
    let selectedResolutions: [String]
    let selectedPerformanceImpact: [String]
    @Binding var selectedProjectId: String?
    let selectedLoaders: [String]
    let gameType: Bool
    @Environment(GameRepository.self)
    private var gameRepository
    @Binding var selectedItem: SidebarItem
    @Binding var searchText: String
    let localResourceFilter: LocalResourceFilter
    @State private var localRefreshToken = UUID()
    @State private var ioViewModel = GameInfoDetailIOViewModel()

    @State private var scannedResources: Set<String> = []
    @State private var header: AnyView?
    @State private var showIconFilePicker = false

    init(
        game: GameVersionInfo,
        query: String,
        dataSource: DataSource,
        selectedVersions: [String],
        selectedCategories: [String],
        selectedFeatures: [String],
        selectedResolutions: [String],
        selectedPerformanceImpact: [String],
        selectedProjectId: Binding<String?>,
        selectedLoaders: [String],
        gameType: Bool,
        selectedItem: Binding<SidebarItem>,
        searchText: Binding<String>,
        localResourceFilter: LocalResourceFilter,
    ) {
        self.game = game
        self.query = query
        self.dataSource = dataSource
        self.selectedVersions = selectedVersions
        self.selectedCategories = selectedCategories
        self.selectedFeatures = selectedFeatures
        self.selectedResolutions = selectedResolutions
        self.selectedPerformanceImpact = selectedPerformanceImpact
        _selectedProjectId = selectedProjectId
        self.selectedLoaders = selectedLoaders
        self.gameType = gameType
        _selectedItem = selectedItem
        _searchText = searchText
        self.localResourceFilter = localResourceFilter
    }

    var body: some View {
        Group {
            if gameType {
                ModrinthDetailView(
                    query: query,
                    selectedVersions: selectedVersions,
                    selectedCategories: selectedCategories,
                    selectedFeatures: selectedFeatures,
                    selectedResolutions: selectedResolutions,
                    selectedPerformanceImpact: selectedPerformanceImpact,
                    selectedProjectId: $selectedProjectId,
                    selectedLoader: selectedLoaders,
                    gameInfo: game,
                    selectedItem: $selectedItem,
                    gameType: gameType,
                    header: header,
                    scannedDetailIds: $scannedResources,
                    dataSource: dataSource,
                    searchText: $searchText,
                )
            } else {
                GameLocalResourceView(
                    game: game,
                    query: query,
                    header: header,
                    selectedItem: $selectedItem,
                    selectedProjectId: $selectedProjectId,
                    refreshToken: localRefreshToken,
                    searchText: $searchText,
                    localFilter: localResourceFilter,
                )
            }
        }
        .onChange(of: game.gameName) { _, _ in
            performRefresh()
        }
        .onChange(of: game.modLoader) { _, _ in
            updateHeaders()
        }
        .onChange(of: game.modVersion) { _, _ in
            updateHeaders()
        }
        .onChange(of: gameType) { _, _ in
            performRefresh()
        }
        .onChange(of: selectedProjectId) { oldValue, newValue in
            if oldValue != nil, newValue == nil {
                resetScanState()
                scanAllResources()
            }
        }
        .onChange(of: query) { _, _ in
            resetScanState()
            scanAllResources()
        }
        .onChange(of: searchText) { _, _ in
            if gameType {
                scanAllResources()
            }
        }
        .onChange(of: dataSource) { _, _ in
            if gameType {
                scanAllResources()
            }
        }
        .onAppear {
            updateHeaders()
            container.core.cacheInfoManager.calculateGameCacheInfo(game.gameName)
        }
        .onChange(of: container.core.cacheInfoManager.cacheInfo) { _, _ in
            updateHeaders()
        }
        .onDisappear {
            scanTask?.cancel()
            scanTask = nil
            iconSaveTask?.cancel()
            iconSaveTask = nil
            clearAllData()
        }
        .fileImporter(
            isPresented: $showIconFilePicker,
            allowedContentTypes: [.png, .jpeg, .gif],
            allowsMultipleSelection: false,
        ) { result in
            handleIconFileSelection(result)
        }
    }

    @State private var scanTask: Task<Void, Never>?
    @State private var iconSaveTask: Task<Void, Never>?

    private func performRefresh() {
        updateHeaders()
        container.core.cacheInfoManager.calculateGameCacheInfo(game.gameName)
        if !gameType {
            triggerLocalRefresh()
        }
        resetScanState()
        scanAllResources()
    }

    private func triggerLocalRefresh() {
        guard !gameType else { return }
        localRefreshToken = UUID()
    }

    private func updateHeaders() {
        let currentGame = gameRepository.games.first { $0.id == game.id } ?? game

        header = AnyView(
            GameHeaderListRow(
                game: currentGame,
                cacheInfo: container.core.cacheInfoManager.cacheInfo,
                query: query,
            ) {
                showIconFilePicker = true
            },
        )
    }

    private func clearAllData() {
        container.core.cacheInfoManager.cacheInfo = CacheInfo(fileCount: 0, totalSize: 0)
        if !gameType {
            localRefreshToken = UUID()
        }
        scannedResources = []
    }

    private func resetScanState() {
        scannedResources = []
    }

    private func scanAllResources() {
        scanTask?.cancel()
        scanTask = Task {
            let detailIds = await ioViewModel.scanAllDetailIds(
                query: query,
                gameName: game.gameName,
            )
            guard !Task.isCancelled else { return }
            scannedResources = detailIds
        }
    }

    private func handleIconFileSelection(_ result: Result<[URL], Error>) {
        let gameName = game.gameName
        iconSaveTask?.cancel()
        iconSaveTask = Task {
            let success = await ioViewModel.saveGameIcon(from: result, gameName: gameName)
            guard !Task.isCancelled, success else { return }

            var updatedGame = gameRepository.games.first { $0.id == game.id } ?? game
            if updatedGame.gameIcon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updatedGame.gameIcon = AppConstants.defaultGameIcon
                do {
                    try await gameRepository.updateGame(updatedGame)
                } catch {
                    container.core.errorHandler.handle(error)
                }
            }
            guard !Task.isCancelled else { return }
            container.ui.iconRefreshNotifier.notifyRefresh(for: gameName)
            updateHeaders()
        }
    }
}
