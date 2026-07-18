//
//  MinecraftFileManager.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CommonCrypto
import Foundation

/// Manages Minecraft version file downloads, verification, and directory setup.
class MinecraftFileManager {
    private let fileManager = FileManager.default
    let coreFilesCount = NSLockingCounter()
    let resourceFilesCount = NSLockingCounter()
    var coreTotalFiles = 0
    var resourceTotalFiles = 0
    var onProgressUpdate: ((String, Int, Int, DownloadType) -> Void)?

    enum DownloadType {
        case core
        case resources
    }

    init() { }

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
            MinecraftFileManagerConstants.metaSubdirectories.map {
                AppPaths.metaDirectory.appendingPathComponent($0)
            } + [
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
    ) {
        let currentCount: Int
        let total: Int

        switch type {
        case .core:
            currentCount = coreFilesCount.increment()
            total = coreTotalFiles
        case .resources:
            currentCount = resourceFilesCount.increment()
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

    func downloadAndSaveFile(
        from url: URL,
        to destinationURL: URL,
        sha1: String?,
        fileNameForNotification: String? = nil,
        type: DownloadType,
    ) async throws {
        do {
            _ = try await DownloadManager.downloadFile(
                urlString: url.absoluteString,
                destinationURL: destinationURL,
                expectedSha1: sha1,
            )

            incrementCompletedFilesCount(
                fileName: fileNameForNotification
                    ?? destinationURL.lastPathComponent,
                type: type,
            )
        } catch {
            if let globalError = error as? GlobalError {
                throw globalError
            } else {
                throw GlobalError.download(
                    i18nKey: "error.download.file_download_failed",
                    level: .notification,
                    message: "Failed to download file from \(url.absoluteString) to \(destinationURL.path): \(error.localizedDescription)",
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
