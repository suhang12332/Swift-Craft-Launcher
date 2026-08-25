//
//  ModScanner+Installation.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Mod installation status checking by file hash lookup.
extension ModScanner {
    /// Returns whether the mod with the given hash is installed for the specified game.
    func checkModInstalledCore(
        hash: String,
        gameName: String,
    ) async -> Bool {
        let cachedMods = await DIContainer.shared.core.modInstallationCache.getAllModsInstalled(for: gameName)
        return cachedMods.contains(hash)
    }

    /// Determines whether a resource is installed in the given directory based on its hash.
    /// - Parameters:
    ///   - hash: The SHA-1 hash of the resource file.
    ///   - dir: The local directory containing the resource (for example, a resourcepack, shader, or datapack directory).
    /// - Returns: `true` if the resource is installed, based on the directory hash cache.
    func isResourceInstalledByHash(
        _ hash: String,
        in dir: URL,
    ) async -> Bool {
        do {
            let hashes = try await scanAllDetailIdsThrowing(in: dir)
            return hashes.contains(hash)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error("Failed to check resource installation status: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
            return false
        }
    }

    /// Checks whether a mod is installed by consulting the cache, throwing on errors.
    func isModInstalled(
        hash: String,
        in modsDir: URL,
    ) async throws -> Bool {
        guard let gameName = extractGameName(from: modsDir) else {
            return false
        }

        return await checkModInstalledCore(hash: hash, gameName: gameName)
    }

    /// Checks whether a mod is installed, reporting failures to the global error handler.
    func isModInstalledReportingErrors(
        hash: String,
        in modsDir: URL,
    ) async -> Bool {
        do {
            return try await isModInstalled(hash: hash, in: modsDir)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error("Failed to check mod installation status: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
            return false
        }
    }
}
