//
//  ModDirectoryWatcherRegistry.swift
//  GameFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Manages a registry of directory watchers for mod directories.
actor ModDirectoryWatcherRegistry {
    private var watchers: [String: ModsDirectoryTreeWatcher] = [:]

    /// Ensures a directory is being watched for mod changes.
    /// - Parameters:
    ///   - directoryURL: The directory URL to watch.
    ///   - gameNameHint: An optional game name hint for scheduling directory hash rebuilds.
    func ensureWatching(directoryURL: URL, gameNameHint: String?) {
        let standardized = directoryURL.standardizedFileURL
        let key = standardized.path
        if watchers[key] != nil {
            return
        }
        guard FileManager.default.fileExists(atPath: key) else {
            return
        }

        let hint = gameNameHint
        let watcher = ModsDirectoryTreeWatcher(path: key) {
            DIContainer.shared.core.modScanner.scheduleDirectoryHashRebuild(
                standardizedDirectoryURL: standardized,
                gameNameHint: hint,
            )
        }
        watchers[key] = watcher
    }
}
