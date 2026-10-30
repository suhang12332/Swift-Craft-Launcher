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
    typealias LoaderResult = ModLoaderSetupResult

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
        loaderResult: LoaderResult?,
    ) async -> GameVersionInfo {
        var updated = gameInfo
        updated.assetIndex = manifest.assetIndex.id
        updated.javaVersion = manifest.javaVersion.majorVersion

        if let loaderResult {
            updated.modVersion = loaderResult.loaderVersion
            updated.modClassPath = loaderResult.classpath
            updated.mainClass = loaderResult.mainClass
            updated.gameArguments = loaderResult.gameArguments
            updated.modJvm = loaderResult.jvmArguments
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
