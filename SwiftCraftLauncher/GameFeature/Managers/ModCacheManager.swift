//
//  ModCacheManager.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides a SQLite-backed cache for parsed mod metadata.
class ModCacheManager {
    static let shared = ModCacheManager()

    private let modCacheDB: ModCacheDatabase
    private let errorHandler: GlobalErrorHandler
    private let queue = DispatchQueue(label: "ModCacheManager.queue")
    private var isInitialized = false

    private init(errorHandler: GlobalErrorHandler = AppServices.errorHandler) {
        self.errorHandler = errorHandler
        let dbPath = AppPaths.gameVersionDatabase.path
        modCacheDB = ModCacheDatabase(dbPath: dbPath)
    }

    /// Ensures the database connection is open.
    /// - Throws: A ``GlobalError`` if initialization fails.
    private func ensureInitialized() throws {
        if !isInitialized {
            let dataDir = AppPaths.dataDirectory
            try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

            try modCacheDB.open()
            isInitialized = true
        }
    }

    /// Stores mod metadata in the cache.
    /// - Parameters:
    ///   - hash: The hash of the mod file.
    ///   - jsonData: The raw JSON bytes to cache.
    /// - Throws: A ``GlobalError`` if the operation fails.
    func set(hash: String, jsonData: Data) throws {
        try queue.sync {
            try ensureInitialized()
            try modCacheDB.saveModCache(hash: hash, jsonData: jsonData)
        }
    }

    /// Stores mod metadata in the cache, handling errors silently.
    /// - Parameters:
    ///   - hash: The hash of the mod file.
    ///   - jsonData: The raw JSON bytes to cache.
    func setSilently(hash: String, jsonData: Data) {
        do {
            try set(hash: hash, jsonData: jsonData)
        } catch {
            errorHandler.handle(error)
        }
    }

    /// Retrieves cached mod data for the given hash.
    /// - Parameter hash: The hash of the mod file.
    /// - Returns: The cached JSON data, or `nil` if not found.
    func get(hash: String) -> Data? {
        queue.sync {
            do {
                try ensureInitialized()
                return try modCacheDB.getModCache(hash: hash)
            } catch {
                errorHandler.handle(error)
                return nil
            }
        }
    }

    /// Clears all cached mod data, handling errors silently.
    func clearSilently() {
        do {
            try queue.sync {
                try ensureInitialized()
                try modCacheDB.clearAllModCaches()
            }
        } catch {
            errorHandler.handle(error)
        }
    }
}
