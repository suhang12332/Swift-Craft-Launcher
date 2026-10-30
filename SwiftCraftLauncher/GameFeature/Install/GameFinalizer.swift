//
//  GameFinalizer.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Turns a downloaded game into a launchable instance: applies the mod loader
/// result, builds the launch command, and writes icon and language settings.
struct GameFinalizer {
    typealias LoaderResult = (loaderVersion: String, classpath: String, mainClass: String)

    /// Writes the chosen icon, falling back to the loader's default icon.
    /// - Returns: Whether an icon exists after the attempt.
    @MainActor
    func saveIcon(gameName: String, modLoader: String, pendingIconData: Data?) async -> Bool {
        guard !gameName.isEmpty else {
            return false
        }

        do {
            if let pendingIconData {
                try GameIconStore.write(pendingIconData, gameName: gameName)
            } else {
                try await GameIconStore.downloadIfMissing(
                    from: URLConfig.API.GitHub.gameIcon(modLoader),
                    gameName: gameName,
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
                    message: "game icon save failed for: \(GameIconStore.iconURL(gameName: gameName).path), error: \(error.localizedDescription)",
                ),
            )
        }

        return GameIconStore.hasIcon(gameName: gameName)
    }

    @MainActor
    func configureLanguage(gameName: String) {
        let mcLang = CommonUtil.minecraftLanguageCode(from: DIContainer.shared.ui.languageManager.selectedLanguage)
        CommonUtil.upsertOptionsEntry(gameName: gameName, key: "lang", value: mcLang)
    }

    /// Applies the loader result and version manifest, then builds the launch command.
    @MainActor
    func finalize(
        gameInfo: GameVersionInfo,
        manifest: MinecraftVersionManifest,
        modLoader: String,
        gameVersion: String,
        loaderVersion: String,
        loaderResult: LoaderResult?,
    ) async -> GameVersionInfo {
        var updated = gameInfo
        updated.assetIndex = manifest.assetIndex.id
        updated.javaVersion = manifest.javaVersion.majorVersion

        if let loaderResult {
            updated.modVersion = loaderResult.loaderVersion
            updated.modClassPath = loaderResult.classpath
            updated.mainClass = loaderResult.mainClass

            switch GameLoader(rawValue: modLoader.lowercased()) ?? .vanilla {
            case .fabric, .quilt:
                let loader: GameLoader = modLoader.lowercased() == GameLoader.fabric.displayName ? .fabric : .quilt
                if let profile = try? await FabricLikeLoaderService.fetchSpecificLoaderVersion(
                    config: .init(gameLoader: loader),
                    for: gameVersion,
                    loaderVersion: loaderVersion,
                ) {
                    updated.modJvm = profile.arguments.jvm ?? []
                    updated.gameArguments = profile.arguments.game ?? []
                }

            case .forge, .neoforge:
                let isForge = modLoader.lowercased() == GameLoader.forge.displayName
                let config = isForge ? ForgeLoaderService.config : NeoForgeLoaderService.config
                if let profile = try? await ForgeLikeLoaderService.fetchSpecificProfile(
                    config: config,
                    for: gameVersion,
                    loaderVersion: loaderVersion,
                ) {
                    updated.gameArguments = profile.arguments.game ?? []
                    updated.modJvm = (profile.arguments.jvm ?? []).map { $0.replacingJVMPlaceholders(gameVersion: gameVersion) }
                }

            case .vanilla:
                break
            }
        } else {
            updated.mainClass = manifest.mainClass
            updated.modVersion = ""
            updated.modClassPath = ""
            updated.modJvm = []
            updated.gameArguments = []
        }

        do {
            updated.launchCommand = try MinecraftLaunchCommandBuilder.buildThrowing(
                manifest: manifest,
                gameInfo: updated,
                launcherVersion: Bundle.main.fullVersion,
            )
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error("Failed to build launch command: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
            updated.launchCommand = []
        }

        return updated
    }
}
