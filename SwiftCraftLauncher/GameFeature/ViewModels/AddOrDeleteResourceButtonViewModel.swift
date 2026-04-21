import Foundation
import SwiftUI
import os

@MainActor
final class AddOrDeleteResourceButtonViewModel: ObservableObject {
    @Published var addButtonState: ModrinthDetailCardView.AddButtonState = .idle
    @Published var isUpdateButtonLoading = false
    @Published var showDeleteAlert = false

    @Published var activeAlert: ResourceButtonAlertType?
    @Published var showGlobalResourceSheet = false
    @Published var showModPackDownloadSheet = false
    @Published var showGameResourceInstallSheet = false

    @Published var preloadedDetail: ModrinthProjectDetail?
    @Published var preloadedCompatibleGames: [GameVersionInfo] = []

    @Published var isDisabled = false
    @Published var currentFileName: String?
    @Published var hasDownloadedInSheet = false
    @Published var oldFileNameForUpdate: String?

    let project: ModrinthProject
    let selectedVersions: [String]
    let selectedLoaders: [String]
    let gameInfo: GameVersionInfo?
    let query: String
    let type: Bool

    let onResourceChanged: (() -> Void)?
    let onToggleDisableState: ((Bool) -> Void)?
    let onResourceUpdated: ((String, String, String, String?) -> Void)?
    let setIsResourceDisabled: (Bool) -> Void
    let addScannedHash: (String) -> Void
    let errorHandler: GlobalErrorHandler
    let modScanner: ModScanner

    var gameRepository: GameRepository?
    var playerListViewModel: PlayerListViewModel?

    init(
        project: ModrinthProject,
        selectedVersions: [String],
        selectedLoaders: [String],
        gameInfo: GameVersionInfo?,
        query: String,
        type: Bool,
        onResourceChanged: (() -> Void)?,
        onResourceUpdated: ((String, String, String, String?) -> Void)?,
        onToggleDisableState: ((Bool) -> Void)?,
        setIsResourceDisabled: @escaping (Bool) -> Void,
        addScannedHash: @escaping (String) -> Void,
        errorHandler: GlobalErrorHandler = AppServices.errorHandler,
        modScanner: ModScanner = AppServices.modScanner
    ) {
        self.project = project
        self.selectedVersions = selectedVersions
        self.selectedLoaders = selectedLoaders
        self.gameInfo = gameInfo
        self.query = query
        self.type = type
        self.onResourceChanged = onResourceChanged
        self.onResourceUpdated = onResourceUpdated
        self.onToggleDisableState = onToggleDisableState
        self.setIsResourceDisabled = setIsResourceDisabled
        self.addScannedHash = addScannedHash
        self.errorHandler = errorHandler
        self.modScanner = modScanner
    }

    func setDependencies(
        gameRepository: GameRepository,
        playerListViewModel: PlayerListViewModel
    ) {
        self.gameRepository = gameRepository
        self.playerListViewModel = playerListViewModel
    }

    var effectiveFileName: String? {
        currentFileName ?? project.fileName
    }

    func syncDisableState(using fileName: String?) {
        isDisabled = ResourceEnableDisableManager.isDisabled(fileName: fileName)
        setIsResourceDisabled(isDisabled)
    }
}
