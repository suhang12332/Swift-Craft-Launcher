//
//  GameInstaller.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Orchestrates game installation: downloads, mod loader setup, and persistence.
///
/// Holds no UI state; progress is published through ``InstallProgressReporter``
/// and the resulting instance is prepared by ``GameFinalizer``.
@MainActor
final class GameInstaller {
    let progress: InstallProgressReporter
    private let finalizer: GameFinalizer

    struct GameSaveInput {
        let gameName: String
        let selectedGameVersion: String
        let selectedModLoader: String
        let specifiedLoaderVersion: String
        let pendingIconData: Data?
    }

    /// Inputs for updating the mod loader on an existing game instance.
    struct GameLoaderUpdateInput {
        let selectedModLoader: String
        let specifiedLoaderVersion: String
    }

    init(
        progress: InstallProgressReporter = InstallProgressReporter(),
        finalizer: GameFinalizer = GameFinalizer(),
    ) {
        self.progress = progress
        self.finalizer = finalizer
    }

    func saveGame(
        input: GameSaveInput,
        playerListViewModel: PlayerListViewModel?,
        gameRepository: GameRepository,
        onSuccess: @escaping () -> Void,
        onError: @escaping (GlobalError, String) -> Void,
        onCancelled: @escaping () -> Void = { },
    ) async {
        if let playerListViewModel {
            guard playerListViewModel.currentPlayer != nil else {
                AppLog.game.error("Unable to save game, no current player selected.")
                onError(
                    GlobalError.configuration(
                        i18nKey: "error.configuration.no_current_player",
                        level: .popup,
                    ),
                    "error.no.current.player.title".localized(),
                )
                return
            }
        }

        progress.reset()
        progress.isDownloading = true

        defer {
            progress.isDownloading = false
        }

        let standardIconPresent = await finalizer.saveIcon(
            gameName: input.gameName,
            modLoader: input.selectedModLoader,
            pendingIconData: input.pendingIconData,
        )
        let persistedGameIcon = standardIconPresent ? AppConstants.defaultGameIcon : ""

        var gameInfo = GameVersionInfo(
            id: UUID(),
            gameName: input.gameName,
            gameIcon: persistedGameIcon,
            gameVersion: input.selectedGameVersion,
            assetIndex: "",
            modLoader: input.selectedModLoader,
        )

        do {
            gameInfo = try await performSetup(
                baseGameInfo: gameInfo,
                selectedGameVersion: input.selectedGameVersion,
                selectedModLoader: input.selectedModLoader,
                specifiedLoaderVersion: input.specifiedLoaderVersion,
            )
            try Task.checkCancellation()
            try await gameRepository.addGame(gameInfo)

            if DIContainer.shared.ui.gameSettingsManager.syncLanguageForNewGames {
                finalizer.configureLanguage(gameName: gameInfo.gameName)
            }

            Task.detached(priority: .utility) { [gameInfo] in
                await DIContainer.shared.core.modScanner.scanGameModsDirectory(game: gameInfo)
            }

            if !Task.isCancelled {
                try? await NotificationManager.send(
                    title: "notification.download.complete.title".localized(),
                    body: String(format: "notification.download.complete.body".localized(), gameInfo.gameName, gameInfo.gameVersion, gameInfo.modLoader),
                )
            }
            onSuccess()
        } catch {
            if isDownloadCancelled(error) {
                AppLog.game.info("Game download task cancelled")
                cleanupGameDirectories(gameName: input.gameName)
                progress.reset()
                onCancelled()
                return
            }
            cleanupGameDirectories(gameName: input.gameName)
            DIContainer.shared.core.errorHandler.handle(error)
        }
    }

    /// Updates the mod loader on an existing game instance, reusing the installation pipeline.
    ///
    /// The game's name, version, icon, memory, JVM arguments, Java path, and environment
    /// variables are preserved; only the loader and launch configuration are replaced. On
    /// failure the existing game record is left untouched and the profile directory is never
    /// deleted, so saves and mods are always preserved.
    func updateGameLoader(
        input: GameLoaderUpdateInput,
        existingGame: GameVersionInfo,
        gameRepository: GameRepository,
        onSuccess: @escaping () -> Void,
    ) async {
        progress.reset()
        progress.isDownloading = true

        defer {
            progress.isDownloading = false
        }

        let baseGameInfo = GameVersionInfo(
            id: UUID(uuidString: existingGame.id) ?? UUID(),
            gameName: existingGame.gameName,
            gameIcon: existingGame.gameIcon,
            gameVersion: existingGame.gameVersion,
            modVersion: "",
            modJvm: [],
            modClassPath: "",
            assetIndex: existingGame.assetIndex,
            modLoader: input.selectedModLoader,
            lastPlayed: existingGame.lastPlayed,
            javaPath: existingGame.javaPath,
            jvmArguments: existingGame.jvmArguments,
            launchCommand: existingGame.launchCommand,
            xms: existingGame.xms,
            xmx: existingGame.xmx,
            javaVersion: existingGame.javaVersion,
            mainClass: existingGame.mainClass,
            gameArguments: existingGame.gameArguments,
            environmentVariables: existingGame.environmentVariables,
        )

        do {
            let finalizedInfo = try await performSetup(
                baseGameInfo: baseGameInfo,
                selectedGameVersion: existingGame.gameVersion,
                selectedModLoader: input.selectedModLoader,
                specifiedLoaderVersion: input.specifiedLoaderVersion,
            )

            try await gameRepository.updateGame(finalizedInfo)

            Task.detached(priority: .utility) { [finalizedInfo] in
                await DIContainer.shared.core.modScanner.scanGameModsDirectory(game: finalizedInfo)
            }

            let loaderLabel = GameLoader(rawValue: finalizedInfo.modLoader)?.labelName ?? finalizedInfo.modLoader
            let loaderDescription = finalizedInfo.modVersion.isEmpty ? loaderLabel : "\(loaderLabel) \(finalizedInfo.modVersion)"
            try? await NotificationManager.send(
                title: "notification.loader.update.complete.title".localized(),
                body: String(
                    format: "notification.loader.update.complete.body".localized(),
                    finalizedInfo.gameName,
                    loaderDescription,
                ),
            )
            onSuccess()
        } catch {
            if isDownloadCancelled(error) {
                AppLog.game.info("Game loader update task cancelled")
                progress.reset()
                return
            }
            DIContainer.shared.core.errorHandler.handle(error)
        }
    }

    /// Core installation steps shared by game creation and loader update.
    ///
    /// Fetches the version manifest, ensures the Java runtime, downloads core and
    /// asset files (idempotent — existing SHA1-verified files are skipped), sets up
    /// the selected mod loader, and finalizes the launch configuration.
    private func performSetup(
        baseGameInfo: GameVersionInfo,
        selectedGameVersion: String,
        selectedModLoader: String,
        specifiedLoaderVersion: String,
    ) async throws -> GameVersionInfo {
        let manifest = try await ModrinthService.fetchVersionInfo(from: selectedGameVersion)

        let javaPath = await DIContainer.shared.system.javaManager.ensureJavaExists(
            version: manifest.javaVersion.component,
        )

        let fileManager = try setupFileManager()
        try await startDownloadProcess(
            fileManager: fileManager,
            manifest: manifest,
            gameName: baseGameInfo.gameName,
        )

        let loaderResult = try await setupModLoaderIfNeeded(
            selectedModLoader: selectedModLoader,
            selectedGameVersion: selectedGameVersion,
            gameName: baseGameInfo.gameName,
            gameIcon: baseGameInfo.gameIcon,
            specifiedLoaderVersion: specifiedLoaderVersion,
        )

        var finalizedInfo = await finalizer.finalize(
            gameInfo: baseGameInfo,
            manifest: manifest,
            modLoader: selectedModLoader,
            gameVersion: selectedGameVersion,
            loaderVersion: specifiedLoaderVersion,
            loaderResult: loaderResult,
        )
        finalizedInfo.javaPath = javaPath
        return finalizedInfo
    }

    private func setupFileManager() throws -> MinecraftFileManager {
        try FileManager.default.createDirectory(at: AppPaths.nativesDirectory, withIntermediateDirectories: true)
        return MinecraftFileManager()
    }

    private func startDownloadProcess(
        fileManager: MinecraftFileManager,
        manifest: MinecraftVersionManifest,
        gameName: String,
    ) async throws {
        let assetIndex = try await downloadAssetIndex(manifest: manifest)

        progress.start(
            coreTotalFiles: 1 + manifest.libraries.count + 1,
            resourcesTotalFiles: assetIndex.objects.count,
        )

        fileManager.onProgressUpdate = { [progress] fileName, completed, total, type in
            Task { @MainActor in
                progress.updateProgress(fileName: fileName, completed: completed, total: total, type: type)
            }
        }

        try await fileManager.downloadVersionFilesThrowing(manifest: manifest, gameName: gameName)
    }

    private func downloadAssetIndex(manifest: MinecraftVersionManifest) async throws -> DownloadedAssetIndex {
        let destinationURL = AppPaths.indexesDirectory.appendingPathComponent("\(manifest.assetIndex.id).json")

        do {
            _ = try await DownloadManager.downloadFile(urlString: manifest.assetIndex.url.absoluteString, destinationURL: destinationURL, expectedSha1: manifest.assetIndex.sha1)
            let assetIndexData = try await Task.detached(priority: .userInitiated) {
                let data = try Data(contentsOf: destinationURL)
                return try JSONDecoder().decode(AssetIndexData.self, from: data)
            }.value
            var totalSize = 0
            for object in assetIndexData.objects.values {
                totalSize += object.size
            }
            return DownloadedAssetIndex(
                id: manifest.assetIndex.id,
                url: manifest.assetIndex.url,
                sha1: manifest.assetIndex.sha1,
                totalSize: totalSize,
                objects: assetIndexData.objects,
            )
        } catch {
            let globalError = GlobalError.from(error)
            throw GlobalError.download(
                i18nKey: "error.download.asset_index_failed",
                level: .notification,
                message: "asset index download failed for version \(manifest.assetIndex.id), url: \(manifest.assetIndex.url), error: \(globalError.localizedDescription)",
            )
        }
    }

    private func setupModLoaderIfNeeded(
        selectedModLoader: String,
        selectedGameVersion: String,
        gameName: String,
        gameIcon: String,
        specifiedLoaderVersion: String,
    ) async throws -> GameFinalizer.LoaderResult? {
        let handler: (any ModLoaderHandler.Type)?

        switch selectedModLoader.lowercased() {
        case GameLoader.fabric.displayName:
            handler = FabricLoaderService.self
        case GameLoader.forge.displayName:
            handler = ForgeLoaderService.self
        case GameLoader.neoforge.displayName:
            handler = NeoForgeLoaderService.self
        case GameLoader.quilt.rawValue:
            handler = QuiltLoaderService.self
        default:
            handler = nil
        }

        guard let handler else { return nil }

        let gameInfo = GameVersionInfo(
            gameName: gameName,
            gameIcon: gameIcon,
            gameVersion: selectedGameVersion,
            assetIndex: "",
            modLoader: selectedModLoader,
        )

        let progressCallback: @Sendable (String, Int, Int) -> Void = { [progress] fileName, completed, total in
            Task { @MainActor in
                progress.updateLoader(fileName: fileName, completed: completed, total: total)
            }
        }

        return try await handler.setupWithSpecificVersionThrowing(
            for: selectedGameVersion,
            loaderVersion: specifiedLoaderVersion,
            gameInfo: gameInfo,
            onProgressUpdate: progressCallback,
        )
    }

    private func isDownloadCancelled(_ error: Error) -> Bool {
        if Task.isCancelled || progress.isCancelled || error is CancellationError {
            return true
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        return false
    }

    private func cleanupGameDirectories(gameName: String) {
        try? MinecraftFileManager.cleanupGameDirectories(gameName: gameName)
    }

    /// Checks whether a game instance with the given name already exists.
    static func isGameNameTaken(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        let gameDir = AppPaths.profileRootDirectory.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: gameDir.path)
    }
}
