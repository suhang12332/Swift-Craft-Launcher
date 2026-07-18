//
//  ModPackDependencyInstaller.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Installs all required dependencies defined by a modpack.
enum ModPackDependencyInstaller {
    static var downloadSemaphoreValue: Int {
        max(1, DIContainer.shared.ui.generalSettingsManager.concurrentDownloads / 4)
    }

    enum DownloadType {
        case files
        case dependencies
        case overrides
    }

    /// Installs all required dependencies for a modpack version.
    static func installVersionDependencies(
        indexInfo: ModrinthIndexInfo,
        gameInfo: GameVersionInfo,
        extractedPath _: URL? = nil,
        onProgressUpdate: ((String, Int, Int, DownloadType) -> Void)? = nil,
    ) async -> Bool {
        let resourceDir = AppPaths.profileDirectory(gameName: gameInfo.gameName)

        async let filesResult = installModPackFiles(
            files: indexInfo.files,
            resourceDir: resourceDir,
            gameInfo: gameInfo,
            onProgressUpdate: onProgressUpdate,
        )

        async let dependenciesResult = installModPackDependencies(
            dependencies: indexInfo.dependencies,
            gameInfo: gameInfo,
            resourceDir: resourceDir,
            onProgressUpdate: onProgressUpdate,
        )

        let (filesSuccess, dependenciesSuccess) = await (filesResult, dependenciesResult)

        if !filesSuccess {
            AppLog.modPack.error("Modpack file installation failed")
            return false
        }

        if !dependenciesSuccess {
            AppLog.modPack.error("Modpack dependency installation failed")
            return false
        }

        return true
    }
}

/// A thread-safe counter for tracking download progress.
final class ModPackCounter {
    private var count = 0
    private let lock = NSLock()

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        count = 0
    }
}
