//
//  GameCreationViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

/// View model for creating a new game instance, managing version selection, mod loader configuration, and game persistence.
@MainActor
@Observable
class GameCreationViewModel: BaseGameFormViewModel {
    var gameIcon = AppConstants.defaultGameIcon
    var iconImage: Image?
    var selectedGameVersion = ""
    var versionTime = ""
    var selectedModLoader = GameLoader.vanilla.displayName {
        didSet {
            updateParentState()
        }
    }

    var selectedLoaderVersion = "" {
        didSet {
            updateDefaultGameName()
        }
    }

    var availableLoaderVersions: [String] = []
    var availableVersions: [String] = []
    var isLoadingLoaderVersions = false

    var pendingIconData: Data?
    var pendingIconURL: URL?
    var didInit = false

    var playerListViewModel: PlayerListViewModel?

    override init(configuration: GameFormConfiguration) {
        super.init(configuration: configuration)
    }

    func setup(gameRepository: GameRepository, playerListViewModel: PlayerListViewModel) {
        self.gameRepository = gameRepository
        self.playerListViewModel = playerListViewModel

        if !didInit {
            didInit = true
            Task {
                await initializeVersionPicker()
            }
        }
        updateParentState()
    }

    override func performInstallation() async {
        await saveGame()
    }

    override func computeIsFormValid() -> Bool {
        let isLoaderVersionValid = selectedModLoader == GameLoader.vanilla.displayName || !selectedLoaderVersion.isEmpty
        return gameNameValidator.isFormValid && isLoaderVersionValid && !isLoadingLoaderVersions
    }

    override func computeIsLoadingLoaderVersions() -> Bool {
        isLoadingLoaderVersions
    }

    var shouldShowProgress: Bool {
        gameInstaller.progress.isDownloading
    }

    var pendingIconURLForDisplay: URL? {
        pendingIconURL ?? URLConfig.API.GitHub.gameIcon(selectedModLoader)
    }

    /// Clears loaded version data when the add-game window closes.
    func clearLoadedVersionsOnClose() {
        if let pendingIconURL, TemporaryFile.isTemporary(pendingIconURL) {
            try? FileManager.default.removeItem(at: pendingIconURL)
        }
        pendingIconData = nil
        pendingIconURL = nil
        iconImage = nil

        availableVersions = []
        availableLoaderVersions = []
        selectedGameVersion = ""
        selectedLoaderVersion = ""
        versionTime = ""
        didInit = false
    }
}
