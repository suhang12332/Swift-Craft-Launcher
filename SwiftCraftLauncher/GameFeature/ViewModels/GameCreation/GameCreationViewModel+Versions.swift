//
//  GameCreationViewModel+Versions.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension GameCreationViewModel {
    /// Populates the version picker with compatible versions for the selected mod loader.
    func initializeVersionPicker() async {
        isLoadingLoaderVersions = true
        updateParentState()

        let includeSnapshots = DIContainer.shared.ui.gameSettingsManager.includeSnapshotsForGameVersions
        let compatibleVersions = await CommonService.compatibleVersions(
            for: selectedModLoader,
            includeSnapshots: includeSnapshots,
        )
        await updateAvailableVersions(compatibleVersions)

        isLoadingLoaderVersions = false
        updateParentState()
    }

    /// Updates the available versions list and selects a default version.
    func updateAvailableVersions(_ versions: [String]) async {
        availableVersions = versions
        if !versions.contains(selectedGameVersion), !versions.isEmpty {
            selectedGameVersion = versions.first ?? ""
        }

        if !versions.isEmpty {
            let targetVersion = versions.contains(selectedGameVersion) ? selectedGameVersion : (versions.first ?? "")
            let timeString = await ModrinthService.queryVersionTime(from: targetVersion)
            versionTime = timeString
            updateDefaultGameName()
        }
    }

    /// Responds to a mod loader change by refreshing compatible versions and loader versions.
    func handleModLoaderChange(_ newLoader: String) {
        pendingIconURL = nil
        pendingIconData = nil
        iconImage = nil

        Task {
            isLoadingLoaderVersions = true
            updateParentState()

            let includeSnapshots = DIContainer.shared.ui.gameSettingsManager.includeSnapshotsForGameVersions
            let compatibleVersions = await CommonService.compatibleVersions(
                for: newLoader,
                includeSnapshots: includeSnapshots,
            )
            await updateAvailableVersions(compatibleVersions)

            if newLoader != GameLoader.vanilla.displayName, !selectedGameVersion.isEmpty {
                await updateLoaderVersions(for: newLoader, gameVersion: selectedGameVersion)
            } else {
                await MainActor.run {
                    availableLoaderVersions = []
                    selectedLoaderVersion = ""
                    updateDefaultGameName()
                }
            }

            isLoadingLoaderVersions = false
            updateParentState()
        }
    }

    /// Responds to a game version change by refreshing loader versions.
    func handleGameVersionChange(_ newGameVersion: String) {
        Task {
            isLoadingLoaderVersions = true
            updateParentState()

            await updateLoaderVersions(for: selectedModLoader, gameVersion: newGameVersion)

            isLoadingLoaderVersions = false
            updateParentState()
        }
    }

    /// Fetches available loader versions for the specified loader and game version.
    func updateLoaderVersions(for loader: String, gameVersion: String) async {
        guard loader != GameLoader.vanilla.displayName, !gameVersion.isEmpty else {
            availableLoaderVersions = []
            selectedLoaderVersion = ""
            updateDefaultGameName()
            return
        }

        var versions: [String] = []

        switch loader.lowercased() {
        case GameLoader.fabric.displayName:
            let fabricVersions = await FabricLoaderService.fetchAllLoaderVersions(for: gameVersion)
            versions = fabricVersions.map(\.loader.version)
        case GameLoader.forge.displayName:
            do {
                let forgeVersions = try await ForgeLoaderService.fetchAllForgeVersions(for: gameVersion)
                versions = forgeVersions.loaders.map(\.id)
            } catch {
                AppLog.game.error("Failed to get Forge versions: \(error.localizedDescription)")
                versions = []
            }
        case GameLoader.neoforge.displayName:
            do {
                let neoforgeVersions = try await NeoForgeLoaderService.fetchAllNeoForgeVersions(for: gameVersion)
                versions = neoforgeVersions.loaders.map(\.id)
            } catch {
                AppLog.game.error("Failed to get NeoForge versions: \(error.localizedDescription)")
                versions = []
            }
        case GameLoader.quilt.rawValue:
            let quiltVersions = await QuiltLoaderService.fetchAllQuiltLoaders(for: gameVersion)
            versions = quiltVersions.map(\.loader.version)
        default:
            versions = []
        }

        availableLoaderVersions = versions
        if !versions.contains(selectedLoaderVersion), !versions.isEmpty {
            selectedLoaderVersion = versions.first ?? ""
        } else if versions.isEmpty {
            selectedLoaderVersion = ""
        }
        updateDefaultGameName()
    }

    /// Regenerates the default game name from the current version and loader selections.
    func updateDefaultGameName() {
        guard !selectedGameVersion.isEmpty else { return }

        let loaderVersion = selectedModLoader == GameLoader.vanilla.displayName ? selectedModLoader : selectedLoaderVersion
        guard !loaderVersion.isEmpty else { return }

        let generatedName = GameNameGenerator.generateGameName(
            gameVersion: selectedGameVersion,
            loaderVersion: loaderVersion,
            modLoader: selectedModLoader,
        )
        gameNameValidator.gameName = generatedName
    }
}
