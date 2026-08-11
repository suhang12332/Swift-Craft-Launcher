//
//  GameSetupUtil.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation
import SwiftUI

/// Manages the complete game installation flow including download, configuration, and setup.
@MainActor
@Observable
class GameSetupUtil {
    var downloadState = DownloadState()
    var fabricDownloadState = DownloadState()
    var forgeDownloadState = DownloadState()
    var neoForgeDownloadState = DownloadState()

    private var downloadTask: Task<Void, Never>?

    struct GameSaveInput {
        let gameName: String
        let selectedGameVersion: String
        let selectedModLoader: String
        let specifiedLoaderVersion: String
        let pendingIconData: Data?
    }

    func saveGame(
        input: GameSaveInput,
        playerListViewModel: PlayerListViewModel?,
        gameRepository: GameRepository,
        onSuccess: @escaping () -> Void,
        onError: @escaping (GlobalError, String) -> Void,
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

        await MainActor.run {
            downloadState.reset()
            downloadState.isDownloading = true
        }

        defer {
            Task { @MainActor in
                downloadState.isDownloading = false
                downloadTask = nil
            }
        }

        let standardIconPresent = await saveGameIcon(
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
            let downloadedManifest = try await ModrinthService.fetchVersionInfo(from: input.selectedGameVersion)

            let javaPath = await DIContainer.shared.system.javaManager.ensureJavaExists(
                version: downloadedManifest.javaVersion.component,
            )

            let fileManager = try await setupFileManager(manifest: downloadedManifest, modLoader: gameInfo.modLoader)

            try await startDownloadProcess(
                fileManager: fileManager,
                manifest: downloadedManifest,
                gameName: input.gameName,
            )

            let modLoaderResult = try await setupModLoaderIfNeeded(
                selectedModLoader: input.selectedModLoader,
                selectedGameVersion: input.selectedGameVersion,
                gameName: input.gameName,
                gameIcon: persistedGameIcon,
                specifiedLoaderVersion: input.specifiedLoaderVersion,
            )

            gameInfo = await finalizeGameInfo(
                gameInfo: gameInfo,
                manifest: downloadedManifest,
                selectedModLoader: input.selectedModLoader,
                selectedGameVersion: input.selectedGameVersion,
                specifiedLoaderVersion: input.specifiedLoaderVersion,
                fabricResult: input.selectedModLoader.lowercased() == GameLoader.fabric.displayName ? modLoaderResult : nil,
                forgeResult: input.selectedModLoader.lowercased() == GameLoader.forge.displayName ? modLoaderResult : nil,
                neoForgeResult: input.selectedModLoader.lowercased() == GameLoader.neoforge.displayName ? modLoaderResult : nil,
                quiltResult: input.selectedModLoader.lowercased() == GameLoader.quilt.rawValue ? modLoaderResult : nil,
            )
            gameInfo.javaPath = javaPath
            gameRepository.addGameSilently(gameInfo)

            if DIContainer.shared.ui.gameSettingsManager.syncLanguageForNewGames {
                configureGameLanguage(for: gameInfo.gameName)
            }

            Task.detached(priority: .utility) { [gameInfo] in
                await DIContainer.shared.core.modScanner.scanGameModsDirectory(game: gameInfo)
            }

            await NotificationManager.sendSilently(
                title: "notification.download.complete.title".localized(),
                body: String(format: "notification.download.complete.body".localized(), gameInfo.gameName, gameInfo.gameVersion, gameInfo.modLoader),
            )
            onSuccess()
        } catch {
            if isSaveGameDownloadCancelled(error) {
                AppLog.game.info("Game download task cancelled")
                await cleanupGameDirectories(gameName: input.gameName)
                await MainActor.run {
                    self.downloadState.reset()
                }
                return
            }
            await cleanupGameDirectories(gameName: input.gameName)
            DIContainer.shared.core.errorHandler.handle(error)
        }
    }

    private func isSaveGameDownloadCancelled(_ error: Error) -> Bool {
        if Task.isCancelled {
            return true
        }
        if downloadState.isCancelled {
            return true
        }
        if error is CancellationError {
            return true
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        return false
    }

    /// Removes partial game files after a failed or cancelled download.
    /// - Parameter gameName: The name of the game instance.
    private func cleanupGameDirectories(gameName: String) async {
        await MinecraftFileManager.cleanupGameDirectoriesSafely(gameName: gameName)
    }

    private func saveGameIcon(
        gameName: String,
        modLoader: String,
        pendingIconData: Data?,
    ) async -> Bool {
        guard !gameName.isEmpty else {
            return false
        }
        let profileDir = AppPaths.profileDirectory(gameName: gameName)
        let iconURL = profileDir.appendingPathComponent(AppConstants.defaultGameIcon)

        do {
            try FileManager.default.createDirectory(at: profileDir, withIntermediateDirectories: true)

            if let data = pendingIconData {
                try data.write(to: iconURL)
            } else if !standardIconFilePresent(at: iconURL) {
                let remoteIconURL = URLConfig.API.GitHub.gameIcon(modLoader)
                _ = try await DownloadManager.downloadFile(
                    urlString: remoteIconURL.absoluteString,
                    destinationURL: iconURL,
                    expectedSha1: nil,
                )
            }
        } catch {
            AppLog.game.error(
                "Game icon save failed, continuing installation: \(error.localizedDescription)",
            )
            DIContainer.shared.core.errorHandler.handle(
                GlobalError.fileSystem(
                    i18nKey: "error.filesystem.image_save_failed",
                    level: .silent,
                    message: "game icon save failed for: \(iconURL.path), error: \(error.localizedDescription)",
                ),
            )
        }

        return standardIconFilePresent(at: iconURL)
    }

    private func standardIconFilePresent(at iconURL: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: iconURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return false
        }
        return true
    }

    private func setupFileManager(manifest _: MinecraftVersionManifest, modLoader _: String) async throws -> MinecraftFileManager {
        let nativesDir = AppPaths.nativesDirectory
        try FileManager.default.createDirectory(at: nativesDir, withIntermediateDirectories: true)
        return MinecraftFileManager()
    }

    private func startDownloadProcess(
        fileManager: MinecraftFileManager,
        manifest: MinecraftVersionManifest,
        gameName: String,
    ) async throws {
        let assetIndex = try await downloadAssetIndex(manifest: manifest)
        let resourceTotalFiles = assetIndex.objects.count

        downloadState.startDownload(
            coreTotalFiles: 1 + manifest.libraries.count + 1,
            resourcesTotalFiles: resourceTotalFiles,
        )

        fileManager.onProgressUpdate = { fileName, completed, total, type in
            Task { @MainActor in
                self.downloadState.updateProgress(fileName: fileName, completed: completed, total: total, type: type)
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
    ) async throws -> (loaderVersion: String, classpath: String, mainClass: String)? {
        let loaderType = selectedModLoader.lowercased()
        let handler: (any ModLoaderHandler.Type)?

        switch loaderType {
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

        let progressCallback: @Sendable (String, Int, Int) -> Void = { [weak self] fileName, completed, total in
            Task { @MainActor in
                guard let self else { return }
                switch loaderType {
                case GameLoader.fabric.displayName:
                    self.fabricDownloadState.updateProgress(fileName: fileName, completed: completed, total: total, type: .core)
                case GameLoader.forge.displayName:
                    self.forgeDownloadState.updateProgress(fileName: fileName, completed: completed, total: total, type: .core)
                case GameLoader.neoforge.displayName:
                    self.neoForgeDownloadState.updateProgress(fileName: fileName, completed: completed, total: total, type: .core)
                case GameLoader.quilt.rawValue:
                    self.fabricDownloadState.updateProgress(fileName: fileName, completed: completed, total: total, type: .core)
                default:
                    break
                }
            }
        }

        return await handler.setupWithSpecificVersion(
            for: selectedGameVersion,
            loaderVersion: specifiedLoaderVersion,
            gameInfo: gameInfo,
            onProgressUpdate: progressCallback,
        )
    }

    private func finalizeGameInfo(
        gameInfo: GameVersionInfo,
        manifest: MinecraftVersionManifest,
        selectedModLoader: String,
        selectedGameVersion: String,
        specifiedLoaderVersion: String,
        fabricResult: (loaderVersion: String, classpath: String, mainClass: String)? = nil,
        forgeResult: (loaderVersion: String, classpath: String, mainClass: String)? = nil,
        neoForgeResult: (loaderVersion: String, classpath: String, mainClass: String)? = nil,
        quiltResult: (loaderVersion: String, classpath: String, mainClass: String)? = nil,
    ) async -> GameVersionInfo {
        var updatedGameInfo = gameInfo
        updatedGameInfo.assetIndex = manifest.assetIndex.id
        updatedGameInfo.javaVersion = manifest.javaVersion.majorVersion

        switch selectedModLoader.lowercased() {
        case GameLoader.fabric.displayName, GameLoader.quilt.rawValue:
            let loader = selectedModLoader.lowercased() == GameLoader.fabric.displayName ? GameLoader.fabric : GameLoader.quilt
            if let result = loader == .fabric ? fabricResult : quiltResult {
                applyModLoaderResult(result, to: &updatedGameInfo)

                if let profile = try? await FabricLikeLoaderService.fetchSpecificLoaderVersion(
                    config: .init(gameLoader: loader),
                    for: selectedGameVersion,
                    loaderVersion: specifiedLoaderVersion,
                ) {
                    updatedGameInfo.modJvm = profile.arguments.jvm ?? []
                    updatedGameInfo.gameArguments = profile.arguments.game ?? []
                }
            }

        case GameLoader.forge.displayName, GameLoader.neoforge.displayName:
            let isForge = selectedModLoader.lowercased() == GameLoader.forge.displayName
            guard let result = isForge ? forgeResult : neoForgeResult else { break }

            applyModLoaderResult(result, to: &updatedGameInfo)

            let config = isForge ? ForgeLoaderService.config : NeoForgeLoaderService.config
            if let profile = try? await ForgeLikeLoaderService.fetchSpecificProfile(config: config, for: selectedGameVersion, loaderVersion: specifiedLoaderVersion) {
                updatedGameInfo.gameArguments = profile.arguments.game ?? []
                updatedGameInfo.modJvm = (profile.arguments.jvm ?? []).map { $0.replacingJVMPlaceholders(gameVersion: selectedGameVersion) }
            }

        default:
            updatedGameInfo.mainClass = manifest.mainClass
        }

        updatedGameInfo.launchCommand = MinecraftLaunchCommandBuilder.build(
            manifest: manifest,
            gameInfo: updatedGameInfo,
            launcherBrand: Bundle.main.appName,
            launcherVersion: Bundle.main.fullVersion,
        )

        return updatedGameInfo
    }

    private func applyModLoaderResult(
        _ result: (loaderVersion: String, classpath: String, mainClass: String),
        to gameInfo: inout GameVersionInfo,
    ) {
        gameInfo.modVersion = result.loaderVersion
        gameInfo.modClassPath = result.classpath
        gameInfo.mainClass = result.mainClass
    }

    /// Checks whether a game instance with the given name already exists.
    /// - Parameter name: The game name to check.
    /// - Returns: `true` if a directory with that name exists; otherwise `false`.
    func checkGameNameDuplicate(_ name: String) async -> Bool {
        guard !name.isEmpty else { return false }

        let fileManager = FileManager.default
        let gameDir = AppPaths.profileRootDirectory.appendingPathComponent(name)
        return fileManager.fileExists(atPath: gameDir.path)
    }

    /// Writes or updates the Minecraft `options.txt` language setting for a game instance.
    /// - Parameter gameName: The name of the game instance.
    private func configureGameLanguage(for gameName: String) {
        let mcLang = CommonUtil.minecraftLanguageCode(from: DIContainer.shared.ui.languageManager.selectedLanguage)
        CommonUtil.upsertOptionsEntry(gameName: gameName, key: "lang", value: mcLang)
    }
}
