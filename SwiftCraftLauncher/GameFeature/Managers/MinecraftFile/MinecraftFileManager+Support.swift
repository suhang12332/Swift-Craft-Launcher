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

// NSLockingCounter removed — replaced by shared AtomicCounter actor.

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
