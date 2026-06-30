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

    var pendingIconData: Data?
    var pendingIconURL: URL?
    var didInit = false
    let gameSettingsManager: GameSettingsManager

    var gameRepository: GameRepository?
    var playerListViewModel: PlayerListViewModel?

    init(
        configuration: GameFormConfiguration,
        errorHandler: GlobalErrorHandler = AppServices.errorHandler,
        gameSettingsManager: GameSettingsManager = AppServices.gameSettingsManager
    ) {
        self.gameSettingsManager = gameSettingsManager
        super.init(configuration: configuration, errorHandler: errorHandler)
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
                guard let gameRepository = gameRepository else { return false }
                return gameRepository.games.contains { $0.gameName == gameName }
            }

            if !isGameSaved {
                do {
                    let profileDir = AppPaths.profileDirectory(gameName: gameName)

                    if FileManager.default.fileExists(atPath: profileDir.path) {
                        try FileManager.default.removeItem(at: profileDir)
                        Logger.shared.info("已删除取消创建的游戏文件夹: \(profileDir.path)")
                    }
                } catch {
                    Logger.shared.error("删除游戏文件夹失败: \(error.localizedDescription)")
                }
            } else {
                Logger.shared.info("游戏已成功保存，跳过删除文件夹: \(gameName)")
            }
        }

        await MainActor.run {
            gameSetupService.downloadState.reset()
            configuration.actions.onCancel()
        }
    }

    override func computeIsDownloading() -> Bool {
        return gameSetupService.downloadState.isDownloading
    }

    override func computeIsFormValid() -> Bool {
        let isLoaderVersionValid = selectedModLoader == GameLoader.vanilla.displayName || !selectedLoaderVersion.isEmpty
        return gameNameValidator.isFormValid && isLoaderVersionValid
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
