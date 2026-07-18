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
class GameCreationViewModel: BaseGameFormViewModel {
    @Published var gameIcon = AppConstants.defaultGameIcon
    @Published var iconImage: Image?
    @Published var selectedGameVersion = ""
    @Published var versionTime = ""
    @Published var selectedModLoader = GameLoader.vanilla.displayName {
        didSet {
            updateParentState()
        }
    }

    @Published var selectedLoaderVersion = "" {
        didSet {
            updateDefaultGameName()
        }
    }

    @Published var availableLoaderVersions: [String] = []
    @Published var availableVersions: [String] = []
    @Published var isLoadingLoaderVersions = false

    var pendingIconData: Data?
    var pendingIconURL: URL?
    var didInit = false

    var gameRepository: GameRepository?
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

    override func performConfirmAction() async {
        startDownloadTask {
            await self.saveGame()
        }
    }

    override func handleCancel() {
        if isDownloading {
            downloadTask?.cancel()
            downloadTask = nil
            gameSetupService.downloadState.cancel()
            Task {
                await performCancelCleanup()
            }
        } else {
            configuration.actions.onCancel()
        }
    }

    override func performCancelCleanup() async {
        let gameName = gameNameValidator.gameName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !gameName.isEmpty {
            let isGameSaved = await MainActor.run {
                guard let gameRepository else { return false }
                return gameRepository.games.contains { $0.gameName == gameName }
            }

            if !isGameSaved {
                do {
                    let profileDir = AppPaths.profileDirectory(gameName: gameName)

                    if FileManager.default.fileExists(atPath: profileDir.path) {
                        try FileManager.default.removeItem(at: profileDir)
                        AppLog.game.info("Deleted cancelled game folder: \(profileDir.path)")
                    }
                } catch {
                    AppLog.game.error("Failed to delete game folder: \(error.localizedDescription)")
                }
            } else {
                AppLog.game.info("Game saved successfully, skipping folder deletion: \(gameName)")
            }
        }

        await MainActor.run {
            gameSetupService.downloadState.reset()
            configuration.actions.onCancel()
        }
    }

    override func computeIsDownloading() -> Bool {
        gameSetupService.downloadState.isDownloading
    }

    override func computeIsFormValid() -> Bool {
        let isLoaderVersionValid = selectedModLoader == GameLoader.vanilla.displayName || !selectedLoaderVersion.isEmpty
        return gameNameValidator.isFormValid && isLoaderVersionValid && !isLoadingLoaderVersions
    }

    override func computeIsLoadingLoaderVersions() -> Bool {
        isLoadingLoaderVersions
    }

    var shouldShowProgress: Bool {
        gameSetupService.downloadState.isDownloading
    }

    var pendingIconURLForDisplay: URL? {
        pendingIconURL ?? URLConfig.API.GitHub.gameIcon(selectedModLoader)
    }

    /// Clears loaded version data when the add-game window closes.
    func clearLoadedVersionsOnClose() {
        availableVersions = []
        availableLoaderVersions = []
        selectedGameVersion = ""
        selectedLoaderVersion = ""
        versionTime = ""
        didInit = false
    }
}
