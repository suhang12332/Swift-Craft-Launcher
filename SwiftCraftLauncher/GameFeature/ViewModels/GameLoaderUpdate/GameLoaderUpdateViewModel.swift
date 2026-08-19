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
/// When the existing game already has a mod loader, only the loader version can be
/// changed — cross-loader switching is not allowed.
///
/// When the existing game is vanilla, the user can choose a mod loader type and
/// version to add. The game version is never changed.
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

    /// The selected mod loader type.
    ///
    /// Mutable only when the existing game is vanilla; fixed otherwise.
    var selectedModLoader: String

    /// The newly selected loader version. Defaults to the game's current loader version.
    var selectedLoaderVersion: String

    /// Loader versions compatible with the selected loader and the game's Minecraft version.
    var availableLoaderVersions: [String] = []
    var isLoadingLoaderVersions = false

    /// Whether the user can change the loader type (only for vanilla games).
    var canChangeLoaderType: Bool {
        existingGame.modLoader == GameLoader.vanilla.displayName
    }

    /// The mod loader types available for selection (excludes vanilla), filtered by game version.
    var availableLoaderTypes: [GameLoader] = []
    var isLoadingLoaderTypes = false

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
            Task {
                await refreshAvailableLoaderTypes()
                await refreshLoaderVersions()
            }
        }
    }

    /// Whether the form is ready to submit.
    var isFormValid: Bool {
        guard !isLoadingLoaderVersions, !isUpdating else { return false }
        if canChangeLoaderType {
            return !selectedLoaderVersion.isEmpty
        }
        return !selectedLoaderVersion.isEmpty && selectedLoaderVersion != existingGame.modVersion
    }

    /// Whether a loader update is currently in progress.
    var isUpdating: Bool {
        gameSetupService.downloadState.isDownloading
    }

    /// A human-readable description of the loader currently installed on the game.
    var currentLoaderDescription: String {
        let loader = GameLoader(rawValue: existingGame.modLoader) ?? .vanilla
        if existingGame.modVersion.isEmpty {
            return loader.labelName
        }
        return "\(loader.labelName) \(existingGame.modVersion)"
    }

    /// Updates the list of available loader types to only those supported by the game's Minecraft version.
    func refreshAvailableLoaderTypes() async {
        await MainActor.run { isLoadingLoaderTypes = true }

        let gameVersion = existingGame.gameVersion
        var supported: [GameLoader] = []

        await withTaskGroup(of: GameLoader?.self) { group in
            for loader in GameLoader.allCases where loader != .vanilla {
                group.addTask {
                    let result = await CommonService.fetchAllLoaderVersionsSilently(
                        type: loader.modrinthLoaderId,
                        minecraftVersion: gameVersion,
                    )
                    return result != nil ? loader : nil
                }
            }
            for await loader in group {
                if let loader {
                    supported.append(loader)
                }
            }
        }

        availableLoaderTypes = GameLoader.allCases.filter { $0 != .vanilla && supported.contains($0) }

        if canChangeLoaderType, !supported.contains(where: { $0.displayName == selectedModLoader }) {
            selectedModLoader = availableLoaderTypes.first?.displayName ?? GameLoader.vanilla.displayName
        }

        await MainActor.run { isLoadingLoaderTypes = false }
    }

    /// Fetches the loader versions available for the selected loader at the game's Minecraft version.
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

    /// Called when the user selects a different loader type. Refreshes the version list.
    func onLoaderTypeChanged() {
        Task { await refreshLoaderVersions() }
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

        await gameSetupService.updateGameLoader(
            input: .init(
                selectedModLoader: selectedModLoader,
                specifiedLoaderVersion: selectedLoaderVersion,
            ),
            existingGame: existingGame,
            gameRepository: gameRepository,
        ) { [weak self] in
            self?.onSuccess?()
        }
    }
}
