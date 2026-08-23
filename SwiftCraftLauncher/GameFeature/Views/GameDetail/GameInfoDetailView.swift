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
    @Environment(PlayerListViewModel.self)
    private var playerListViewModel
    @Binding var selectedItem: SidebarItem
    @Binding var searchText: String
    @Binding var localResourceFilter: LocalResourceFilter
    @State private var localRefreshToken = UUID()
    @State private var ioViewModel = GameInfoDetailIOViewModel()

    @State private var scannedResources: Set<String> = []
    @State private var header: AnyView?
    @State private var showIconFilePicker = false
    @State private var showGameNamePopover = false
    @State private var editedGameName = ""
    @State private var nameEditorError: String?
    @State private var isNameDuplicate = false
    @State private var isCheckingName = false
    @State private var isSavingGameName = false

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

        let headerView = GameHeaderListRow(
            game: currentGame,
            cacheInfo: container.core.cacheInfoManager.cacheInfo,
            query: query,
        ) {
            showIconFilePicker = true
        } onNameTap: {
            beginGameNameEditing()
        }
        .popover(isPresented: $showGameNamePopover, arrowEdge: .bottom) {
            gameNameEditorPopover
        }
        header = AnyView(headerView)
    }

    private var gameNameEditorPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("game.form.name".localized())
                .font(.headline)
            TextField("game.form.name.placeholder".localized(), text: $editedGameName)
                .textFieldStyle(.roundedBorder)
                .onSubmit(saveGameName)
            if isNameDuplicate {
                Text("game.form.name.duplicate".localized())
                    .foregroundStyle(.red)
                    .font(.caption)
            } else if let nameEditorError {
                Text(nameEditorError)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            HStack {
                Spacer()
                Button("common.confirm".localized(), action: saveGameName)
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        isSavingGameName
                            || isCurrentGameRunning
                            || isCurrentGameLaunching
                            || isCheckingName
                            || isNameDuplicate
                            || editedGameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || editedGameName == game.gameName,
                    )
            }
        }
        .padding()
        .frame(width: 300)
        .task(id: editedGameName) {
            await validateEditedGameName()
        }
    }

    private func beginGameNameEditing() {
        editedGameName = game.gameName
        nameEditorError = nil
        isNameDuplicate = false
        showGameNamePopover = true
    }

    private var currentUserID: String {
        playerListViewModel.currentPlayer?.id ?? ""
    }

    private var isCurrentGameRunning: Bool {
        container.core.gameProcessManager.isGameRunningForAnyUser(gameId: game.id)
    }

    private var isCurrentGameLaunching: Bool {
        container.core.gameStatusManager.isGameLaunching(gameId: game.id, userId: currentUserID)
    }

    private func validateEditedGameName() async {
        let newName = editedGameName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != game.gameName else {
            isNameDuplicate = false
            isCheckingName = false
            return
        }

        isCheckingName = true
        do {
            let exists = try await gameRepository.gameNameExists(newName, excludingID: game.id)
            guard !Task.isCancelled else { return }
            isNameDuplicate = exists
        } catch {
            guard !Task.isCancelled else { return }
            isNameDuplicate = true
            nameEditorError = GlobalError.from(error).localizedDescription
        }
        isCheckingName = false
    }

    private func saveGameName() {
        guard !isSavingGameName else { return }
        let newName = editedGameName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != game.gameName else { return }

        isSavingGameName = true
        nameEditorError = nil
        Task { @MainActor in
            do {
                guard !isCurrentGameRunning, !isCurrentGameLaunching else {
                    isSavingGameName = false
                    return
                }
                guard var updatedGame = gameRepository.getGame(by: game.id) else {
                    isSavingGameName = false
                    return
                }
                guard try await !gameRepository.gameNameExists(newName, excludingID: game.id) else {
                    isNameDuplicate = true
                    nameEditorError = "game.form.name.duplicate".localized()
                    isSavingGameName = false
                    return
                }

                let oldDirectory = AppPaths.profileDirectory(gameName: updatedGame.gameName)
                let newDirectory = AppPaths.profileDirectory(gameName: newName)
                guard !FileManager.default.fileExists(atPath: newDirectory.path) else {
                    isNameDuplicate = true
                    nameEditorError = "game.form.name.duplicate".localized()
                    isSavingGameName = false
                    return
                }

                if FileManager.default.fileExists(atPath: oldDirectory.path) {
                    try FileManager.default.moveItem(at: oldDirectory, to: newDirectory)
                }
                updatedGame.gameName = newName

                do {
                    try await gameRepository.updateGame(updatedGame)
                } catch {
                    if FileManager.default.fileExists(atPath: newDirectory.path),
                       !FileManager.default.fileExists(atPath: oldDirectory.path) {
                        try? FileManager.default.moveItem(at: newDirectory, to: oldDirectory)
                    }
                    throw error
                }

                showGameNamePopover = false
                isSavingGameName = false
                container.ui.iconRefreshNotifier.notifyRefresh(for: nil)
                performRefresh()
            } catch {
                isSavingGameName = false
                container.core.errorHandler.handle(GlobalError.from(error))
            }
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
