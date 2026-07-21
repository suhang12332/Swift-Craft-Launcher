//
//  ModScanner+InstallationCache.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// In-memory caches for directory file hashes and per-game mod installation state.
extension ModScanner {
    /// Caches the set of file hashes for each directory, keyed by the absolute directory path.
    actor DirectoryHashCache {
        private var cache: [String: Set<String>] = [:]

        init() { }

        func get(for directory: URL) -> Set<String>? {
            cache[directory.standardizedFileURL.path]
        }

        func set(_ hashes: Set<String>, for directory: URL) {
            cache[directory.standardizedFileURL.path] = hashes
        }

        func remove(for directory: URL) {
            cache.removeValue(forKey: directory.standardizedFileURL.path)
        }
    }

    actor ModInstallationCache {
        private var cache: [String: Set<String>] = [:]

        init() { }

        func addHash(_ hash: String, to gameName: String) {
            if var cached = cache[gameName] {
                cached.insert(hash)
                cache[gameName] = cached
            } else {
                cache[gameName] = [hash]
            }
        }

        func removeHash(_ hash: String, from gameName: String) {
            if var cached = cache[gameName] {
                cached.remove(hash)
                cache[gameName] = cached
            }
        }

        func getAllModsInstalled(for gameName: String) -> Set<String> {
            cache[gameName] ?? Set<String>()
        }

        func hasCache(for gameName: String) -> Bool {
            cache[gameName] != nil
        }

        func setAllModsInstalled(for gameName: String, hashes: Set<String>) {
            cache[gameName] = hashes
        }

        func removeGame(gameName: String) {
            cache.removeValue(forKey: gameName)
        }
    }

    func addModHash(_ hash: String, to gameName: String) {
        Task {
            await DIContainer.shared.core.modInstallationCache.addHash(hash, to: gameName)
        }
    }

    func removeModHash(_ hash: String, from gameName: String) {
        Task {
            await DIContainer.shared.core.modInstallationCache.removeHash(hash, from: gameName)
        }
    }

    func getAllModsInstalled(for gameName: String) async -> Set<String> {
        await DIContainer.shared.core.modInstallationCache.getAllModsInstalled(for: gameName)
    }

    func clearModCache(for gameName: String) async {
        await DIContainer.shared.core.modInstallationCache.removeGame(gameName: gameName)
    }
}
