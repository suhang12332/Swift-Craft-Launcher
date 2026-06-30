//
//  GameInfoDetailView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

/// Displays game information details with local and remote resource browsing.
import SwiftUI
import UniformTypeIdentifiers

struct GameInfoDetailView: View {
    let game: GameVersionInfo

    @Binding var query: String
    @Binding var dataSource: DataSource
    @Binding var selectedVersions: [String]
    @Binding var selectedCategories: [String]
    @Binding var selectedFeatures: [String]
    @Binding var selectedResolutions: [String]
    @Binding var selectedPerformanceImpact: [String]
    @Binding var selectedProjectId: String?
    @Binding var selectedLoaders: [String]
    @Binding var gameType: Bool
    @EnvironmentObject private var gameRepository: GameRepository
    @Binding var selectedItem: SidebarItem
    @Binding var searchText: String
    @Binding var localResourceFilter: LocalResourceFilter
    @StateObject private var cacheInfoManager: CacheInfoManager
    @State private var localRefreshToken = UUID()
    @StateObject private var ioViewModel = GameInfoDetailIOViewModel()

    @State private var scannedResources: Set<String> = []

    @State private var header: AnyView?

    @State private var showIconFilePicker = false
    private let errorHandler: GlobalErrorHandler
    private let iconRefreshNotifier: IconRefreshNotifier

    init(
        game: GameVersionInfo,
        query: Binding<String>,
        dataSource: Binding<DataSource>,
        selectedVersions: Binding<[String]>,
        selectedCategories: Binding<[String]>,
        selectedFeatures: Binding<[String]>,
        selectedResolutions: Binding<[String]>,
        selectedPerformanceImpact: Binding<[String]>,
        selectedProjectId: Binding<String?>,
        selectedLoaders: Binding<[String]>,
        gameType: Binding<Bool>,
        selectedItem: Binding<SidebarItem>,
        searchText: Binding<String>,
        localResourceFilter: Binding<LocalResourceFilter>,
        errorHandler: GlobalErrorHandler = AppServices.errorHandler,
        iconRefreshNotifier: IconRefreshNotifier = AppServices.iconRefreshNotifier,
        cacheInfoManager: CacheInfoManager = AppServices.cacheInfoManager
    ) {
        self.game = game
        _cacheInfoManager = StateObject(wrappedValue: cacheInfoManager)
        _query = query
        _dataSource = dataSource
        _selectedVersions = selectedVersions
        _selectedCategories = selectedCategories
        _selectedFeatures = selectedFeatures
        _selectedResolutions = selectedResolutions
        _selectedPerformanceImpact = selectedPerformanceImpact
        _selectedProjectId = selectedProjectId
        _selectedLoaders = selectedLoaders
        _gameType = gameType
        _selectedItem = selectedItem
        _searchText = searchText
        _localResourceFilter = localResourceFilter
        self.errorHandler = errorHandler
        self.iconRefreshNotifier = iconRefreshNotifier
    }

    var body: some View {
        return Group {
            if gameType {
                GameRemoteResourceView(
                    game: game,
                    query: $query,
                    selectedVersions: $selectedVersions,
                    selectedCategories: $selectedCategories,
                    selectedFeatures: $selectedFeatures,
                    selectedResolutions: $selectedResolutions,
                    selectedPerformanceImpact: $selectedPerformanceImpact,
                    selectedProjectId: $selectedProjectId,
                    selectedLoaders: $selectedLoaders,
                    selectedItem: $selectedItem,
                    gameType: $gameType,
                    header: header,
                    scannedDetailIds: $scannedResources,
                    dataSource: $dataSource,
                    searchText: $searchText
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
                    localFilter: $localResourceFilter
                )
            }
        }
        .onChange(of: game.gameName) { _, _ in
            performRefresh()
        }
        .onChange(of: gameType) { _, _ in
            performRefresh()
        }
        .onChange(of: selectedProjectId) { oldValue, newValue in
            if oldValue != nil && newValue == nil {
                resetScanState()
                scanAllResources()
            }
        }
        .onChange(of: query) { _, _ in
            resetScanState()
            scanAllResources()
        }
        .onAppear {
            updateHeaders()
            cacheInfoManager.calculateGameCacheInfo(game.gameName)
        }
        .onChange(of: cacheInfoManager.cacheInfo) { _, _ in
            updateHeaders()
        }
        .onDisappear {
            clearAllData()
        }
        .fileImporter(
            isPresented: $showIconFilePicker,
            allowedContentTypes: [.png, .jpeg, .gif],
            allowsMultipleSelection: false
        ) { result in
            handleIconFileSelection(result)
        }
    }

    private func performRefresh() {
        updateHeaders()
        cacheInfoManager.calculateGameCacheInfo(game.gameName)
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
                cacheInfo: cacheInfoManager.cacheInfo,
                query: query
            ) {
                showIconFilePicker = true
            }
        )
    }

    private func clearAllData() {
        cacheInfoManager.cacheInfo = CacheInfo(fileCount: 0, totalSize: 0)
        if !gameType {
            localRefreshToken = UUID()
        }
        scannedResources = []
    }

    private func resetScanState() {
        scannedResources = []
    }

    private func scanAllResources() {
        Task {
            scannedResources = await ioViewModel.scanAllDetailIds(
                query: query,
                gameName: game.gameName
            )
        }
    }

    private func handleIconFileSelection(_ result: Result<[URL], Error>) {
        let gameName = game.gameName
        Task {
            let success = await ioViewModel.saveGameIcon(from: result, gameName: gameName)
            if success {
                var updatedGame = gameRepository.games.first { $0.id == game.id } ?? game
                if updatedGame.gameIcon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    updatedGame.gameIcon = AppConstants.defaultGameIcon
                    do {
                        try await gameRepository.updateGame(updatedGame)
                    } catch {
                        errorHandler.handle(error)
                    }
                }
                iconRefreshNotifier.notifyRefresh(for: gameName)
                updateHeaders()
            }
        }
    }
}
