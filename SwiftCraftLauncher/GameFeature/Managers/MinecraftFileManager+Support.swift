//
//  MinecraftFileManager+Support.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Support types and helpers for MinecraftFileManager.
enum MinecraftFileManagerConstants {
    static let metaSubdirectories = [
        AppConstants.DirectoryNames.versions,
        AppConstants.DirectoryNames.libraries,
        AppConstants.DirectoryNames.natives,
        AppConstants.DirectoryNames.assets,
        "\(AppConstants.DirectoryNames.assets)/indexes",
        "\(AppConstants.DirectoryNames.assets)/objects",
    ]
    static let assetChunkSize = 500
    static let downloadTimeout: TimeInterval = 30
    static let memoryBufferSize = 1024 * 1024
}

/// A thread-safe counter using `NSLock`.
final class NSLockingCounter {
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

extension Library {
    var artifactPath: String? {
        downloads.artifact.path
    }
    var artifactURL: URL? {
        downloads.artifact.url
    }
    var artifactSHA1: String? {
        downloads.artifact.sha1
    }
}
