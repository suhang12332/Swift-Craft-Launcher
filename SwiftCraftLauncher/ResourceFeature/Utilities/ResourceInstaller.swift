//
//  ResourceInstaller.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Downloads a Modrinth version's primary file into a game instance and records
/// its hash in the mod cache.
///
/// Single-resource installation and modpack dependency installation both go
/// through this path so directory selection, hash caching, and mod tracking
/// stay consistent.
enum ResourceInstaller {
    struct InstalledFile {
        /// The on-disk location of the downloaded file.
        let url: URL
        /// The file name reported by Modrinth.
        let fileName: String
        /// The SHA-1 of the downloaded file, when it could be computed.
        let hash: String?
    }

    /// Installs the primary file of `version` into `gameInfo`'s resource directory.
    /// - Parameters:
    ///   - version: The Modrinth version to install.
    ///   - projectDetail: The project the version belongs to.
    ///   - gameInfo: The target game instance.
    ///   - resourceType: The resource type used to select the destination directory.
    /// - Returns: The installed file, or `nil` when the version has no primary file.
    /// - Throws: A download error when the file cannot be fetched.
    static func install(
        version: ModrinthProjectDetailVersion,
        projectDetail: ModrinthProjectDetail,
        gameInfo: GameVersionInfo,
        resourceType: String,
    ) async throws -> InstalledFile? {
        guard let primaryFile = ModrinthService.filterPrimaryFiles(from: version.files) else {
            return nil
        }

        let fileURL = try await DownloadManager.downloadResource(
            for: gameInfo,
            urlString: primaryFile.url,
            resourceType: resourceType,
            expectedSha1: primaryFile.hashes.sha1,
        )

        var detail = projectDetail
        detail.fileName = primaryFile.filename
        detail.type = resourceType

        var hash: String?
        if let sha1 = await DIContainer.shared.core.modScanner.sha1Hash(of: fileURL) {
            hash = sha1
            DIContainer.shared.core.modScanner.saveToCache(hash: sha1, detail: detail)
            if resourceType.lowercased() == ResourceType.mod.rawValue {
                DIContainer.shared.core.modScanner.addModHash(sha1, to: gameInfo.gameName)
            }
        }

        return InstalledFile(url: fileURL, fileName: primaryFile.filename, hash: hash)
    }
}
