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

    /// Returns all jar and zip files in the directory with their hashes and cached details.
    public func localModDetails(in dir: URL) -> [(
        file: URL, hash: String, detail: ModrinthProjectDetail?
    )] {
        do {
            return try localModDetailsThrowing(in: dir)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error("Failed to get local mod details: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
            return []
        }
    }

    /// Returns all jar and zip files in the directory with their hashes and cached details, throwing on errors.
    public func localModDetailsThrowing(in dir: URL) throws -> [(
        file: URL, hash: String, detail: ModrinthProjectDetail?
    )] {
        try scanDirectoryForDetails(in: dir)
    }

    /// Synchronously checks whether a mod is installed by consulting the cache.
    func isModInstalledSync(hash: String, in modsDir: URL) -> Bool {
        do {
            return try isModInstalledSyncThrowing(
                hash: hash,
                in: modsDir,
            )
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error("Failed to check mod installation status: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
            return false
        }
    }

    /// Synchronously checks whether a mod is installed, throwing on errors.
    func isModInstalledSyncThrowing(
        hash: String,
        in modsDir: URL,
    ) throws -> Bool {
        guard let gameName = extractGameName(from: modsDir) else {
            return false
        }

        let semaphore = DispatchSemaphore(value: 0)
        var result = false

        Task {
            result = await checkModInstalledCore(hash: hash, gameName: gameName)
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Asynchronously checks whether a mod is installed, returning the result via a completion handler.
    func isModInstalled(
        hash: String,
        in modsDir: URL,
        completion: @escaping (Bool) -> Void,
    ) {
        Task {
            do {
                let result = try await isModInstalledThrowing(
                    hash: hash,
                    in: modsDir,
                )
                completion(result)
            } catch {
                let globalError = GlobalError.from(error)
                AppLog.game.error(
                    "Failed to check mod installation status: \(globalError.localizedDescription)",
                )
                DIContainer.shared.core.errorHandler.handle(globalError)
                completion(false)
            }
        }
    }

    /// Asynchronously checks whether a mod is installed.
    func isModInstalledThrowing(
        hash: String,
        in modsDir: URL,
    ) async throws -> Bool {
        guard let gameName = extractGameName(from: modsDir) else {
            return false
        }

        return await checkModInstalledCore(hash: hash, gameName: gameName)
    }
}
