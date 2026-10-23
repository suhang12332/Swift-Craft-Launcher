//
//  TemporaryDirectory.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Categories of temporary directories created by the launcher.
///
/// The on-disk folder name comes from ``AppConstants/TemporaryDirectoryNames``,
/// so creation and cleanup always agree about where a purpose lives.
enum TemporaryDirectoryPurpose: CaseIterable {
    case modpackDownload
    case modpackExtraction
    case modpackImport
    case modpackURLDownload
    case modpackExport
    case minecraftNativeExtraction
    case playerSkin
    case playerCape
    case gameIconPreview
    case downloadStaging

    /// Purposes owned by the modpack installation flow.
    ///
    /// Cleanup for one install must not touch export or native-extraction
    /// directories, so the install flow uses this list instead of `allCases`.
    static let modpackInstall: [Self] = [
        .modpackDownload,
        .modpackExtraction,
        .modpackImport,
        .modpackURLDownload,
    ]

    /// The folder name under the system temporary directory.
    var directoryName: String {
        switch self {
        case .modpackDownload: AppConstants.TemporaryDirectoryNames.modpackDownload
        case .modpackExtraction: AppConstants.TemporaryDirectoryNames.modpackExtraction
        case .modpackImport: AppConstants.TemporaryDirectoryNames.modpackImport
        case .modpackURLDownload: AppConstants.TemporaryDirectoryNames.modpackURLDownload
        case .modpackExport: AppConstants.TemporaryDirectoryNames.modpackExport
        case .minecraftNativeExtraction: AppConstants.TemporaryDirectoryNames.minecraftNativeExtraction
        case .playerSkin: AppConstants.TemporaryDirectoryNames.playerSkin
        case .playerCape: AppConstants.TemporaryDirectoryNames.playerCape
        case .gameIconPreview: AppConstants.TemporaryDirectoryNames.gameIconPreview
        case .downloadStaging: AppConstants.TemporaryDirectoryNames.downloadStaging
        }
    }
}

/// A uniquely named temporary directory owned by the caller.
struct TemporaryDirectory {
    let url: URL

    /// Creates `<temporaryDirectory>/<purpose>/<UUID>`.
    /// - Parameter purpose: The category the directory belongs to.
    /// - Throws: A file system error when the directory cannot be created.
    init(purpose: TemporaryDirectoryPurpose) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(purpose.directoryName, isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory
    }

    /// Removes this directory and everything inside it.
    func remove() {
        try? FileManager.default.removeItem(at: url)
    }

    /// Removes every directory created for `purpose`.
    ///
    /// Use this for application-level cleanup. Prefer `remove()` on an owned
    /// instance while another session may still be using its own directory.
    /// - Parameter purpose: The category to remove.
    static func removeAll(purpose: TemporaryDirectoryPurpose) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(purpose.directoryName, isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
    }
}

/// A uniquely named temporary file inside a purpose directory.
struct TemporaryFile {
    let url: URL

    /// Builds `<temporaryDirectory>/<purpose>/<fileName>` and ensures the
    /// purpose directory exists. The file itself is not created.
    /// - Parameters:
    ///   - purpose: The category the file belongs to.
    ///   - fileName: An optional file name; defaults to a UUID.
    /// - Throws: A file system error when the purpose directory cannot be created.
    init(purpose: TemporaryDirectoryPurpose, fileName: String? = nil) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(purpose.directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent(fileName ?? UUID().uuidString)
    }

    /// Writes `data` to the file.
    /// - Parameter data: The bytes to write.
    /// - Throws: A file system error when the file cannot be written.
    func write(_ data: Data) throws {
        try data.write(to: url)
    }

    /// Removes the file if it exists.
    func remove() {
        try? FileManager.default.removeItem(at: url)
    }

    /// Whether `url` points at a launcher-managed temporary file.
    /// - Parameter url: The URL to check.
    /// - Returns: `true` when the URL lives inside one of the known purpose directories.
    static func isTemporary(_ url: URL) -> Bool {
        let root = FileManager.default.temporaryDirectory.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(root + "/") else { return false }

        let relative = path.dropFirst(root.count + 1)
        guard let purposeName = relative.split(separator: "/").first else { return false }
        return TemporaryDirectoryPurpose.allCases.contains { $0.directoryName == purposeName }
    }
}
