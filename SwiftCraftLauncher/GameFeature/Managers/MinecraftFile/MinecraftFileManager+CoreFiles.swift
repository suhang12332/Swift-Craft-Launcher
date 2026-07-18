//
//  MinecraftFileManager+CoreFiles.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Core file download extension for MinecraftFileManager.
extension MinecraftFileManager {
    func downloadCoreFiles(manifest: MinecraftVersionManifest) async throws {
        coreTotalFiles = calculateTotalFiles(manifest)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                try await self?.downloadClientJar(manifest: manifest)
            }
            group.addTask { [weak self] in
                try await self?.downloadLibraries(manifest: manifest)
            }
            group.addTask { [weak self] in
                try await self?.downloadLoggingConfig(manifest: manifest)
            }

            try await group.waitForAll()
        }
    }

    private func downloadClientJar(
        manifest: MinecraftVersionManifest,
    ) async throws {
        let versionDir = AppPaths.versionsDirectory.appendingPathComponent(
            manifest.id,
        )
        let destinationURL = versionDir.appendingPathComponent(
            "\(manifest.id).jar",
        )

        do {
            _ = try await DownloadManager.downloadFile(
                urlString: manifest.downloads.client.url.absoluteString,
                destinationURL: destinationURL,
                expectedSha1: manifest.downloads.client.sha1,
            )
            incrementCompletedFilesCount(
                fileName: "client.jar",
                type: .core,
            )
        } catch {
            if let globalError = error as? GlobalError {
                throw globalError
            } else {
                throw GlobalError.download(
                    i18nKey: "error.download.client_jar_failed",
                    level: .notification,
                    message: "Failed to download client.jar for manifestId=\(manifest.id), url=\(manifest.downloads.client.url.absoluteString): \(error.localizedDescription)",
                )
            }
        }
    }

    private func downloadLibraries(
        manifest: MinecraftVersionManifest,
    ) async throws {
        let osxLibraries = manifest.libraries.filter {
            shouldDownloadLibrary($0, minecraftVersion: manifest.id)
        }

        let semaphore = AsyncSemaphore(
            value: DIContainer.shared.ui.generalSettingsManager.concurrentDownloads,
        )

        let metaDirectory = AppPaths.metaDirectory
        let minecraftVersion = manifest.id

        try await withThrowingTaskGroup(of: Void.self) { group in
            for library in osxLibraries {
                group.addTask { [weak self] in
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }

                    try await self?.downloadLibrary(
                        library,
                        metaDirectory: metaDirectory,
                        minecraftVersion: minecraftVersion,
                    )
                }
            }
            try await group.waitForAll()
        }
    }

    private func downloadLibrary(
        _ library: Library,
        metaDirectory: URL,
        minecraftVersion: String,
    ) async throws {
        guard shouldDownloadLibrary(library, minecraftVersion: minecraftVersion) else {
            return
        }

        let destinationURL: URL
        if let existingPath = library.downloads.artifact.path {
            if existingPath.hasPrefix("/") {
                destinationURL = URL(fileURLWithPath: existingPath)
            } else {
                destinationURL = metaDirectory.appendingPathComponent(AppConstants.DirectoryNames.libraries)
                    .appendingPathComponent(existingPath)
            }
        } else {
            let fullPath = CommonService.convertMavenCoordinateToPath(library.name)
            destinationURL = URL(fileURLWithPath: fullPath)
        }

        guard let artifactURL = library.downloads.artifact.url else {
            throw GlobalError.download(
                i18nKey: "error.download.missing_library_url",
                level: .notification,
                message: "Library artifact URL is nil for \(library.name)",
            )
        }

        do {
            let urlString = artifactURL.absoluteString
            _ = try await DownloadManager.downloadFile(
                urlString: urlString,
                destinationURL: destinationURL,
                expectedSha1: library.downloads.artifact.sha1,
            )
            await handleLibraryDownloadComplete(
                library: library,
                metaDirectory: metaDirectory,
                minecraftVersion: minecraftVersion,
            )
        } catch {
            if let globalError = error as? GlobalError {
                throw globalError
            } else {
                throw GlobalError.download(
                    i18nKey: "error.download.library_failed",
                    level: .notification,
                    message: "Failed to download library \(library.name) from \(artifactURL.absoluteString): \(error.localizedDescription)",
                )
            }
        }
    }

    func downloadNativeLibrary(
        library: Library,
        classifiers: [String: LibraryArtifact],
        metaDirectory: URL,
        minecraftVersion: String,
    ) async throws {
        guard let natives = library.natives else { return }

        let osKey = natives.keys.first { isNativeClassifier($0, minecraftVersion: minecraftVersion) }
        guard let platformKey = osKey,
              let classifierKey = natives[platformKey],
              let nativeArtifact = classifiers[classifierKey] else {
            return
        }

        let destinationURL: URL
        if let existingPath = nativeArtifact.path {
            if existingPath.hasPrefix("/") {
                destinationURL = URL(fileURLWithPath: existingPath)
            } else {
                destinationURL = metaDirectory.appendingPathComponent(AppConstants.DirectoryNames.natives)
                    .appendingPathComponent(existingPath)
            }
        } else {
            let relativePath = CommonService.mavenCoordinateToRelativePath(library.name)
                ?? "\(library.name.replacingOccurrences(of: ":", with: "-")).jar"
            destinationURL = metaDirectory.appendingPathComponent(AppConstants.DirectoryNames.natives)
                .appendingPathComponent(relativePath)
        }

        guard let nativeURL = nativeArtifact.url else {
            throw GlobalError.download(
                i18nKey: "error.download.missing_native_url",
                level: .notification,
                message: "Native artifact URL is nil for \(library.name), classifier=\(classifierKey)",
            )
        }

        do {
            _ = try await DownloadManager.downloadFile(
                urlString: nativeURL.absoluteString,
                destinationURL: destinationURL,
                expectedSha1: nativeArtifact.sha1,
            )

            incrementCompletedFilesCount(
                fileName: library.name,
                type: .core,
            )
        } catch {
            if let globalError = error as? GlobalError {
                throw globalError
            } else {
                throw GlobalError.download(
                    i18nKey: "error.download.native_library_failed",
                    level: .notification,
                    message: "Failed to download native library \(library.name) from \(nativeURL.absoluteString): \(error.localizedDescription)",
                )
            }
        }
    }

    private func downloadLoggingConfig(
        manifest: MinecraftVersionManifest,
    ) async throws {
        let loggingFile = manifest.logging.client.file
        let versionDir = AppPaths.metaDirectory.appendingPathComponent(
            AppConstants.DirectoryNames.versions,
        )
        .appendingPathComponent(manifest.id)

        let destinationURL = versionDir.appendingPathComponent(loggingFile.id)

        do {
            _ = try await DownloadManager.downloadFile(
                urlString: loggingFile.url.absoluteString,
                destinationURL: destinationURL,
                expectedSha1: loggingFile.sha1,
            )
            incrementCompletedFilesCount(
                fileName: "logging.config",
                type: .core,
            )
        } catch {
            if let globalError = error as? GlobalError {
                throw globalError
            } else {
                throw GlobalError.download(
                    i18nKey: "error.download.logging_config_failed",
                    level: .notification,
                    message: "Failed to download logging config \(loggingFile.id) for manifestId=\(manifest.id): \(error.localizedDescription)",
                )
            }
        }
    }

    func handleLibraryDownloadComplete(
        library: Library,
        metaDirectory: URL,
        minecraftVersion: String,
    ) async {
        incrementCompletedFilesCount(
            fileName: library.name,
            type: .core,
        )

        if let classifiers = library.downloads.classifiers {
            do {
                try await downloadNativeLibrary(
                    library: library,
                    classifiers: classifiers,
                    metaDirectory: metaDirectory,
                    minecraftVersion: minecraftVersion,
                )
            } catch {
                AppLog.game.error("Failed to download native libraries")
            }
        }
    }
}
