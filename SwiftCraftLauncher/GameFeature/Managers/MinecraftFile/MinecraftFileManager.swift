//
//  MinecraftFileManager.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CommonCrypto
import Foundation

/// Manages Minecraft version file downloads, verification, and directory setup.
class MinecraftFileManager: @unchecked Sendable {
    private let fileManager = FileManager.default
    let coreFilesCount = AtomicCounter()
    let resourceFilesCount = AtomicCounter()
    var coreTotalFiles = 0
    var resourceTotalFiles = 0
    var onProgressUpdate: (@Sendable (String, Int, Int, DownloadType) -> Void)?
    private let diagnosticsID: UUID?

    enum DownloadType {
        case core
        case resources
    }

    init(diagnosticsID: UUID? = nil) {
        self.diagnosticsID = diagnosticsID
    }

    /// Cleans up game directories, logging errors instead of throwing.
    static func cleanupGameDirectoriesSafely(gameName: String) async {
        do {
            try MinecraftFileManager().cleanupGameDirectories(gameName: gameName)
        } catch {
            AppLog.modPack.error("Failed to clean up game directories: \(error.localizedDescription)")
        }
    }

    /// Creates the profile directory structure for a game.
    static func createProfileDirectories(for gameName: String) async -> Bool {
        let profileDirectory = AppPaths.profileDirectory(gameName: gameName)
        let subdirs = AppPaths.profileSubdirectories.map {
            profileDirectory.appendingPathComponent($0)
        }
        for dir in [profileDirectory] + subdirs {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                AppLog.modPack.error("Failed to create directory: \(dir.path), error: \(error.localizedDescription)")
                DIContainer.shared.core.errorHandler.handle(
                    GlobalError.fileSystem(i18nKey: "error.filesystem.directory_creation_failed", level: .notification),
                )
                return false
            }
        }
        return true
    }

    /// Splits index info into downloadable files and required dependencies.
    static func calculateInstallationCounts(from indexInfo: ModrinthIndexInfo) -> ([ModrinthIndexFile], [ModrinthIndexProjectDependency]) {
        let filesToDownload = indexInfo.files.filter { file in
            if let env = file.env, let client = env.client, client.lowercased() == "unsupported" {
                return false
            }
            return true
        }
        let requiredDependencies = indexInfo.dependencies.filter { $0.dependencyType == "required" }
        return (filesToDownload, requiredDependencies)
    }

    func cleanupGameDirectories(gameName: String) throws {
        let profileDirectory = AppPaths.profileDirectory(gameName: gameName)

        guard fileManager.fileExists(atPath: profileDirectory.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: profileDirectory)
        } catch {
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.game_deletion_failed",
                level: .notification,
                message: "Failed to remove profile directory \(profileDirectory.path) for gameName=\(gameName): \(error.localizedDescription)",
            )
        }
    }

    func downloadVersionFiles(
        manifest: MinecraftVersionManifest,
        gameName: String,
    ) async -> Bool {
        do {
            try await downloadVersionFilesThrowing(
                manifest: manifest,
                gameName: gameName,
            )
            return true
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error(
                "Failed to download Minecraft version files: \(globalError.localizedDescription)",
            )
            DIContainer.shared.core.errorHandler.handle(globalError)
            return false
        }
    }

    func downloadVersionFilesThrowing(
        manifest: MinecraftVersionManifest,
        gameName: String,
    ) async throws {
        try createDirectories(manifestId: manifest.id, gameName: gameName)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                try await self?.downloadCoreFiles(manifest: manifest)
            }
            group.addTask { [weak self] in
                try await self?.downloadAssets(manifest: manifest)
            }

            try await group.waitForAll()
        }
    }

    func calculateTotalFiles(_ manifest: MinecraftVersionManifest) -> Int {
        let applicableLibraries = manifest.libraries.filter {
            shouldDownloadLibrary($0, minecraftVersion: manifest.id)
        }

        let nativeLibraries = applicableLibraries.compactMap { (library: Library) -> Library? in
            guard let classifiers = library.downloads.classifiers,
                  let natives = library.natives else { return nil }

            let osKey = natives.keys.first { isNativeClassifier($0, minecraftVersion: manifest.id) }
            guard let platformKey = osKey,
                  let classifierKey = natives[platformKey],
                  classifiers[classifierKey] != nil else { return nil }

            return library
        }.count

        return 1 + applicableLibraries.count + nativeLibraries + 2
    }

    func isNativeClassifier(_ key: String, minecraftVersion: String? = nil) -> Bool {
        MacRuleEvaluator.isPlatformIdentifierSupported(key, minecraftVersion: minecraftVersion)
    }

    func createDirectories(
        manifestId: String,
        gameName: String,
    ) throws {
        let profileDirectory = AppPaths.profileDirectory(gameName: gameName)
        let directoriesToCreate =
            MinecraftFileManagerConstants.metaSubdirectories + [
                AppPaths.metaDirectory.appendingPathComponent(AppConstants.DirectoryNames.versions)
                    .appendingPathComponent(manifestId),
                profileDirectory,
            ]
        let profileSubfolders = AppPaths.profileSubdirectories.map {
            profileDirectory.appendingPathComponent($0)
        }
        let allDirectories = directoriesToCreate + profileSubfolders

        for directory in allDirectories where !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                )
            } catch {
                throw GlobalError.fileSystem(
                    i18nKey: "error.filesystem.directory_creation_failed",
                    level: .notification,
                    message: "Failed to create directory \(directory.path) for manifestId=\(manifestId): \(error.localizedDescription)",
                )
            }
        }
    }

    func incrementCompletedFilesCount(
        fileName: String,
        type: DownloadType,
    ) async {
        let currentCount: Int
        let total: Int

        switch type {
        case .core:
            currentCount = await coreFilesCount.increment()
            total = coreTotalFiles
        case .resources:
            currentCount = await resourceFilesCount.increment()
            total = resourceTotalFiles
        }

        onProgressUpdate?(fileName, currentCount, total, type)
    }

    func verifyExistingFile(
        at url: URL,
        expectedSha1: String,
    ) async throws -> Bool {
        let fileSha1 = try await calculateFileSHA1(at: url)
        return fileSha1 == expectedSha1
    }

    func calculateFileSHA1(at url: URL) async throws -> String {
        try SHA1Calculator.sha1(ofFileAt: url)
    }

    /// Downloads a file, verifies its SHA1, and increments the progress counter.
    ///
    /// Non-`GlobalError` failures are wrapped into a `GlobalError.download` with
    /// the given `i18nKey` and `errorMessage` (the underlying error detail is
    /// appended automatically) so each caller keeps its own error copy.
    func downloadAndSaveFile(
        from url: URL,
        to destinationURL: URL,
        sha1: String?,
        fileNameForNotification: String? = nil,
        type: DownloadType,
        i18nKey: String = "error.download.file_download_failed",
        errorMessage: String? = nil,
    ) async throws {
        let diagnostics = InstallationDiagnosticsLogger.shared
        let fileType: String
        switch type {
        case .core:
            fileType = "core"
        case .resources:
            fileType = "resource"
        }
        diagnosticsID.map {
            diagnostics.record(
                $0,
                stage: "download.start",
                message: "type=\(fileType) url=\(url.absoluteString) destination=\(destinationURL.path) expectedSHA1=\(sha1 ?? "none")",
            )
        }
        do {
            _ = try await DownloadManager.downloadFile(
                urlString: url.absoluteString,
                destinationURL: destinationURL,
                expectedSha1: sha1,
            )

            if let fileNameForNotification {
                await incrementCompletedFilesCount(
                    fileName: fileNameForNotification,
                    type: type,
                )
            }
            diagnosticsID.map {
                diagnostics.record(
                    $0,
                    stage: "download.success",
                    message: "type=\(fileType) url=\(url.absoluteString) destination=\(destinationURL.path)",
                )
            }
        } catch {
            diagnosticsID.map {
                diagnostics.record(
                    $0,
                    stage: "download.failure",
                    message: "type=\(fileType) url=\(url.absoluteString) destination=\(destinationURL.path) error=\(error.localizedDescription)",
                )
            }
            if let globalError = error as? GlobalError {
                throw globalError
            } else {
                throw GlobalError.download(
                    i18nKey: i18nKey,
                    level: .notification,
                    message: "\(errorMessage ?? "Failed to download file from \(url.absoluteString) to \(destinationURL.path)"): \(error.localizedDescription)",
                )
            }
        }
    }

    func shouldDownloadLibrary(_ library: Library, minecraftVersion: String? = nil) -> Bool {
        LibraryFilter.shouldDownloadLibrary(library, minecraftVersion: minecraftVersion)
    }

    func isLibraryAllowedOnOSX(_ rules: [Rule]?) -> Bool {
        guard let rules, !rules.isEmpty else { return true }
        return MacRuleEvaluator.isAllowed(rules)
    }
}
