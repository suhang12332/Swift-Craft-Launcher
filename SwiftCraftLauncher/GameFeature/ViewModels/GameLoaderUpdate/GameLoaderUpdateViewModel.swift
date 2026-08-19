//
//  GameLoaderUpdateViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// View model for changing the loader version on an existing game instance.
///
/// The Minecraft version and loader type are fixed to the existing game's values;
/// only the loader version can be changed — cross-loader switching is not allowed.
/// Downloads are tracked through the shared ``GameSetupUtil`` pipeline, whose file
/// downloads are idempotent (SHA1-verified files are skipped), so re-running it on
/// an installed game only fetches what changed.
@MainActor
@Observable
final class GameLoaderUpdateViewModel {
    /// The existing game instance being updated.
    let existingGame: GameVersionInfo

    /// The installation pipeline reused for loader version changes.
    let gameSetupService = GameSetupUtil()

    /// The mod loader type, fixed to the existing game's loader (cannot be changed).
    let selectedModLoader: String

    /// The newly selected loader version. Defaults to the game's current loader version.
    var selectedLoaderVersion: String

    /// Loader versions compatible with the game's fixed Minecraft version and loader.
    var availableLoaderVersions: [String] = []
    var isLoadingLoaderVersions = false

    private var updateTask: Task<Void, Never>?
    private var didInit = false
    private var gameRepository: GameRepository?

    /// Invoked on the main actor once the updated record has been persisted.
    var onSuccess: (() -> Void)?

    init(existingGame: GameVersionInfo) {
        self.existingGame = existingGame
        selectedModLoader = existingGame.modLoader
        selectedLoaderVersion = existingGame.modLoader == GameLoader.vanilla.displayName ? "" : existingGame.modVersion
    }

    /// Binds the repository and kicks off the initial loader-version fetch.
    func setup(gameRepository: GameRepository) {
        self.gameRepository = gameRepository
        if !didInit {
            didInit = true
            Task { await refreshLoaderVersions() }
        }
    }

    /// Whether the form is ready to submit.
    var isFormValid: Bool {
        let isLoaderVersionValid = selectedModLoader == GameLoader.vanilla.displayName || !selectedLoaderVersion.isEmpty
        return isLoaderVersionValid && !isLoadingLoaderVersions && !isUpdating
    }

    /// Whether a loader update is currently in progress.
    var isUpdating: Bool {
        gameSetupService.downloadState.isDownloading
    }

    /// Whether the download progress section should be visible.
    var shouldShowProgress: Bool {
        isUpdating
    }

    /// A human-readable description of the loader currently installed on the game.
    var currentLoaderDescription: String {
        let loader = GameLoader(rawValue: existingGame.modLoader) ?? .vanilla
        if existingGame.modVersion.isEmpty {
            return loader.labelName
        }
        return "\(loader.labelName) \(existingGame.modVersion)"
    }

    /// Fetches the loader versions available for the fixed loader at the game's fixed version.
    func refreshLoaderVersions() async {
        guard selectedModLoader != GameLoader.vanilla.displayName else {
            await MainActor.run {
                availableLoaderVersions = []
                selectedLoaderVersion = ""
            }
            return
        }

        await MainActor.run {
            isLoadingLoaderVersions = true
        }

        let versions = await CommonService.fetchLoaderVersionStrings(
            for: selectedModLoader,
            gameVersion: existingGame.gameVersion,
        )

        await MainActor.run {
            availableLoaderVersions = versions
            if !versions.contains(selectedLoaderVersion) {
                selectedLoaderVersion = versions.first ?? ""
            } else if versions.isEmpty {
                selectedLoaderVersion = ""
            }
            isLoadingLoaderVersions = false
        }
    }

    /// Starts the loader update through the installation pipeline.
    func confirm() {
        updateTask?.cancel()
        updateTask = Task { await updateLoader() }
    }

    /// Cancels an in-progress loader update. The existing game is left intact.
    func cancel() {
        guard isUpdating else { return }
        updateTask?.cancel()
        gameSetupService.downloadState.cancel()
    }

    /// Cancels any pending task when the view disappears.
    func cleanup() {
        if isUpdating {
            updateTask?.cancel()
        }
    }

    /// Runs the loader update and persists the result.
    private func updateLoader() async {
        guard let gameRepository else {
            AppLog.game.error("GameRepository not set for loader update")
            return
        }

        let loaderVersion = selectedModLoader == GameLoader.vanilla.displayName
            ? selectedModLoader
            : selectedLoaderVersion

        await gameSetupService.updateGameLoader(
            input: .init(
                selectedModLoader: selectedModLoader,
                specifiedLoaderVersion: loaderVersion,
            ),
            existingGame: existingGame,
            gameRepository: gameRepository,
        ) { [weak self] in
            self?.onSuccess?()
        }
    }
}
