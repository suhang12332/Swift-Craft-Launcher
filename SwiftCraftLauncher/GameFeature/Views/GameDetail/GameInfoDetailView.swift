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
    private enum NameValidationState: Equatable {
        case idle
        case checking
        case valid
        case duplicate
        case failed(String)
    }

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
    @State private var showIconFilePicker = false
    @State private var showGameNamePopover = false
    @State private var editedGameName = ""
    @State private var nameValidationState: NameValidationState = .idle
    @State private var nameValidationRequestID = UUID()
    @State private var isSavingGameName = false
    @State private var isGameRunningForNameEdit = false

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
            container.core.cacheInfoManager.calculateGameCacheInfo(game.gameName)
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

    private var header: AnyView {
        let currentGame = gameRepository.games.first { $0.id == game.id } ?? game

        return AnyView(
            GameHeaderListRow(
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
            },
        )
    }

    private var gameNameEditorPopover: some View {
        HStack(spacing: 12) {
            TextField("game.form.name.placeholder".localized(), text: $editedGameName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 340)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(nameValidationMessage == nil ? Color.clear : Color.red, lineWidth: 1)
                }
                .help(nameValidationMessage ?? "")
                .onSubmit {
                    guard canConfirmGameName else { return }
                    saveGameName()
                }
            Button("common.confirm".localized(), action: saveGameName)
                .buttonStyle(.borderedProminent)
                .disabled(!canConfirmGameName)
        }
        .padding()
        .onChange(of: editedGameName) { _, newValue in
            validateEditedGameName(newValue)
        }
    }

    private var nameValidationMessage: String? {
        switch nameValidationState {
        case .duplicate:
            "game.form.name.duplicate".localized()
        case let .failed(message):
            message
        case .idle, .checking, .valid:
            nil
        }
    }

    private func beginGameNameEditing() {
        editedGameName = currentGameName
        nameValidationState = .idle
        nameValidationRequestID = UUID()
        isGameRunningForNameEdit = isCurrentGameRunning
        showGameNamePopover = true
    }

    private var currentGameName: String {
        gameRepository.getGame(by: game.id)?.gameName ?? game.gameName
    }

    private var isCurrentGameRunning: Bool {
        container.core.gameProcessManager.isGameRunningForAnyUser(gameId: game.id)
    }

    private var canConfirmGameName: Bool {
        nameValidationState == .valid
            && !isSavingGameName
            && !isGameRunningForNameEdit
    }

    private func validateEditedGameName(_ value: String) {
        let newName = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestID = UUID()
        nameValidationRequestID = requestID

        guard !newName.isEmpty, newName != currentGameName else {
            nameValidationState = .idle
            return
        }

        nameValidationState = .checking
        Task { @MainActor in
            do {
                let exists = try await gameRepository.gameNameExists(newName, excludingID: game.id)
                guard requestID == nameValidationRequestID else { return }
                nameValidationState = exists ? .duplicate : .valid
            } catch {
                guard requestID == nameValidationRequestID else { return }
                nameValidationState = .failed(GlobalError.from(error).localizedDescription)
            }
        }
    }

    private func saveGameName() {
        guard canConfirmGameName else { return }
        let newName = editedGameName.trimmingCharacters(in: .whitespacesAndNewlines)

        isSavingGameName = true
        Task { @MainActor in
            defer { isSavingGameName = false }
            do {
                guard !isCurrentGameRunning else {
                    isGameRunningForNameEdit = true
                    return
                }
                guard var updatedGame = gameRepository.getGame(by: game.id) else { return }
                guard try await !gameRepository.gameNameExists(newName, excludingID: game.id) else {
                    nameValidationState = .duplicate
                    return
                }

                let oldDirectory = AppPaths.profileDirectory(gameName: updatedGame.gameName)
                let newDirectory = AppPaths.profileDirectory(gameName: newName)
                guard !FileManager.default.fileExists(atPath: newDirectory.path) else {
                    nameValidationState = .duplicate
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
                container.ui.iconRefreshNotifier.notifyRefresh(for: nil)
                performRefresh()
            } catch {
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
            }
        }
    }
}
