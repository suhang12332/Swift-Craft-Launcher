//
//  GameInfoDetailView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// Displays game information details with local and remote resource browsing.
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct GameInfoDetailView: View {
    @Environment(DIContainer.self)
    private var container
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
    @Environment(GameRepository.self)
    private var gameRepository
    @Binding var selectedItem: SidebarItem
    @Binding var searchText: String
    @Binding var localResourceFilter: LocalResourceFilter
    @State private var localRefreshToken = UUID()
    @State private var ioViewModel = GameInfoDetailIOViewModel()

    @State private var scannedResources: Set<String> = []
    @State private var header: AnyView?
    @State private var showIconFilePicker = false

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
    ) {
        self.game = game
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
    }

    var body: some View {
        Group {
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
                    localFilter: $localResourceFilter,
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
            } onNameTap: {
                presentGameNameEditor()
            },
        )
    }

    private func presentGameNameEditor() {
        let alert = NSAlert()
        alert.messageText = "game.form.name".localized()
        alert.informativeText = "game.form.name.placeholder".localized()

        let textField = NSTextField(string: game.gameName)
        textField.placeholderString = "game.form.name.placeholder".localized()
        textField.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        alert.accessoryView = textField
        alert.addButton(withTitle: "common.confirm".localized())
        alert.addButton(withTitle: "common.cancel".localized())

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }
        guard !gameRepository.games.contains(where: { $0.id != game.id && $0.gameName == newName }) else {
            container.core.errorHandler.handle(
                GlobalError.validation(
                    i18nKey: "game.form.name.duplicate",
                    level: .notification,
                ),
            )
            return
        }

        guard var updatedGame = gameRepository.games.first(where: { $0.id == game.id }) else { return }
        let oldDirectory = AppPaths.profileDirectory(gameName: updatedGame.gameName)
        let newDirectory = AppPaths.profileDirectory(gameName: newName)

        do {
            if updatedGame.gameName != newName {
                guard !FileManager.default.fileExists(atPath: newDirectory.path) else {
                    throw GlobalError.validation(
                        i18nKey: "game.form.name.duplicate",
                        level: .notification,
                    )
                }
                if FileManager.default.fileExists(atPath: oldDirectory.path) {
                    try FileManager.default.moveItem(at: oldDirectory, to: newDirectory)
                }
            }

            updatedGame.gameName = newName
            Task { @MainActor in
                do {
                    try await gameRepository.updateGame(updatedGame)
                    container.ui.iconRefreshNotifier.notifyRefresh(for: nil)
                    performRefresh()
                } catch {
                    if FileManager.default.fileExists(atPath: newDirectory.path),
                       !FileManager.default.fileExists(atPath: oldDirectory.path) {
                        try? FileManager.default.moveItem(at: newDirectory, to: oldDirectory)
                    }
                    container.core.errorHandler.handle(GlobalError.from(error))
                }
            }
        } catch {
            if FileManager.default.fileExists(atPath: newDirectory.path),
               !FileManager.default.fileExists(atPath: oldDirectory.path) {
                try? FileManager.default.moveItem(at: newDirectory, to: oldDirectory)
            }
            container.core.errorHandler.handle(GlobalError.from(error))
        }
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
        Task {
            scannedResources = await ioViewModel.scanAllDetailIds(
                query: query,
                gameName: game.gameName,
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
                        container.core.errorHandler.handle(error)
                    }
                }
                container.ui.iconRefreshNotifier.notifyRefresh(for: gameName)
                updateHeaders()
            }
        }
    }
}
