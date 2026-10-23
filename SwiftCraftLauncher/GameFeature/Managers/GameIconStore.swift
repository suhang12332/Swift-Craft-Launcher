//
//  GameIconStore.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Reads and writes the icon file of a game instance profile.
///
/// Both game creation (loader icon or user-picked image) and modpack installation
/// (project icon) write the same file, so the naming and location live here.
enum GameIconStore {
    /// The on-disk location of the instance icon.
    static func iconURL(gameName: String) -> URL {
        AppPaths.profileDirectory(gameName: gameName)
            .appendingPathComponent(AppConstants.defaultGameIcon)
    }

    /// Whether the instance already has an icon file on disk.
    static func hasIcon(gameName: String) -> Bool {
        var isDirectory: ObjCBool = false
        let path = iconURL(gameName: gameName).path
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && !isDirectory.boolValue
    }

    /// Writes icon data to the instance profile, creating the directory if needed.
    /// - Parameters:
    ///   - data: The encoded image data.
    ///   - gameName: The name of the game instance.
    /// - Throws: A file system error when the data cannot be written.
    static func write(_ data: Data, gameName: String) throws {
        guard !gameName.isEmpty else { return }

        let url = iconURL(gameName: gameName)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        try data.write(to: url)
    }

    /// Downloads an icon only when the instance does not have one yet.
    /// - Parameters:
    ///   - remoteURL: The icon URL to download from.
    ///   - gameName: The name of the game instance.
    /// - Returns: `true` when an icon exists after the call.
    /// - Throws: A download error when the icon cannot be fetched.
    @discardableResult
    static func downloadIfMissing(from remoteURL: URL, gameName: String) async throws -> Bool {
        guard !gameName.isEmpty else { return false }
        if hasIcon(gameName: gameName) {
            return true
        }

        let url = iconURL(gameName: gameName)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        _ = try await DownloadManager.downloadFile(
            urlString: remoteURL.absoluteString,
            destinationURL: url,
            expectedSha1: nil,
        )
        return hasIcon(gameName: gameName)
    }
}
