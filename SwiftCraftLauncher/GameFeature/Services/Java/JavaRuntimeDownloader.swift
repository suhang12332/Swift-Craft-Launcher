//
//  JavaRuntimeDownloader.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import ZIPFoundation

/// Downloads and installs Java runtime distributions.
class JavaRuntimeDownloader {
    private let progressActor = ProgressActor()
    private let cancelActor = CancelActor()

    func setProgressCallback(_ callback: @escaping (String, Int, Int) -> Void) {
        Task {
            await progressActor.setCallback(callback)
        }
    }

    func setCancelCallback(_ callback: @escaping () -> Bool) {
        Task {
            await cancelActor.setCallback(callback)
        }
    }

    func downloadJavaRuntime(for version: String) async throws {
        let dir = AppPaths.runtimeDirectory.appendingPathComponent(version)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }

        if let bundledVersionURL = DIContainer.shared.system.javaRuntimeService.specialJavaRuntimeURL(for: version) {
            try await downloadBundledJavaRuntime(version: version, url: bundledVersionURL)
            return
        }

        let manifestURL = try await DIContainer.shared.system.javaRuntimeService.getManifestURL(for: version)
        let manifestData = try await fetchDataFromURL(manifestURL)
        guard let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
              let files = manifest["files"] as? [String: Any] else {
            throw GlobalError.validation(
                i18nKey: "error.validation.manifest_parse_failed",
                level: .notification,
                message: "failed to parse Java runtime manifest from URL: \(manifestURL)",
            )
        }

        let targetDirectory = AppPaths.runtimeDirectory.appendingPathComponent(version)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        let totalFiles = files
            .compactMap { filePath, fileInfo -> Int? in
                guard let fileData = fileInfo as? [String: Any],
                      let fileType = fileData["type"] as? String,
                      fileType == "file" else {
                    return nil
                }

                let localFilePath = targetDirectory.appendingPathComponent(filePath)
                let fileExists = FileManager.default.fileExists(atPath: localFilePath.path)

                return fileExists ? nil : 1
            }
            .reduce(0, +)

        let semaphore = AsyncSemaphore(
            value: DIContainer.shared.ui.generalSettingsManager.concurrentDownloads,
        )

        let counter = Counter()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for (filePath, fileInfo) in files {
                group.addTask { [progressActor, cancelActor, self] in
                    if await cancelActor.shouldCancel() {
                        AppLog.game.info("Java download cancelled")
                        throw GlobalError.download(
                            i18nKey: "error.download.cancelled",
                            level: .notification,
                            message: "Java runtime download cancelled by user",
                        )
                    }

                    guard let fileData = fileInfo as? [String: Any],
                          let downloads = fileData["downloads"] as? [String: Any] else {
                        return
                    }

                    let fileType = fileData["type"] as? String
                    let isExecutable = fileData["executable"] as? Bool ?? false

                    guard let raw = downloads["raw"] as? [String: Any] else {
                        AppLog.game.error("File \(filePath) does not have RAW format, skipping")
                        return
                    }

                    guard let fileURL = raw["url"] as? String else {
                        return
                    }

                    let expectedSHA1 = raw["sha1"] as? String

                    let localFilePath = targetDirectory.appendingPathComponent(filePath)

                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }

                    let fileExistsBefore = FileManager.default.fileExists(atPath: localFilePath.path)

                    _ = try await DownloadManager.downloadFile(
                        urlString: fileURL,
                        destinationURL: localFilePath,
                        expectedSha1: expectedSHA1,
                    )

                    if fileType == "file", isExecutable {
                        try setExecutablePermission(for: localFilePath)
                    }

                    if fileType == "file", !fileExistsBefore {
                        do {
                            let fileAttributes = try FileManager.default.attributesOfItem(atPath: localFilePath.path)
                            if let fileSize = fileAttributes[.size] as? Int64, fileSize > 0 {
                                let completed = await counter.increment()
                                await progressActor.callProgressUpdate(filePath, completed, totalFiles)
                            }
                        } catch {
                            AppLog.game.error("Unable to verify file \(filePath) download status: \(error.localizedDescription)")
                        }
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    private func fetchDataFromURL(_ urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw GlobalError.validation(
                i18nKey: "error.validation.invalid_url",
                level: .notification,
                message: "invalid URL: \(urlString)",
            )
        }
        return try await APIClient.get(url: url)
    }

    private func setExecutablePermission(for filePath: URL) throws {
        let fileManager = FileManager.default

        let currentAttributes = try fileManager.attributesOfItem(atPath: filePath.path)
        var currentPermissions = currentAttributes[.posixPermissions] as? UInt16 ?? 0o644

        currentPermissions |= 0o111

        try fileManager.setAttributes([.posixPermissions: currentPermissions], ofItemAtPath: filePath.path)
    }

    private func downloadBundledJavaRuntime(version: String, url: URL) async throws {
        let targetDirectory = AppPaths.runtimeDirectory.appendingPathComponent(version)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        let tempZipPath = targetDirectory.appendingPathComponent("temp_java.zip")

        try await downloadZipWithProgress(
            from: url,
            to: tempZipPath,
            fileName: "\(version).zip",
        )

        try await extractAndProcessBundledJavaRuntime(
            zipPath: tempZipPath,
            targetDirectory: targetDirectory,
        )

        await progressActor.callProgressUpdate("Java runtime \(version) installation complete", 1, 1)
    }

    private func extractAndProcessBundledJavaRuntime(zipPath: URL, targetDirectory: URL) async throws {
        let fileManager = FileManager.default

        let finalJreBundlePath = targetDirectory.appendingPathComponent("jre.bundle")

        if fileManager.fileExists(atPath: finalJreBundlePath.path) {
            try fileManager.removeItem(at: finalJreBundlePath)
        }

        do {
            try extractSpecificFolderFromZip(
                zipPath: zipPath,
                destinationPath: finalJreBundlePath,
            )
        } catch {
            AppLog.game.error("Failed to extract Java runtime: \(error.localizedDescription)")

            throw GlobalError.validation(
                i18nKey: "error.validation.extract_failed",
                level: .notification,
                message: "failed to extract Java runtime from \(zipPath.path), error: \(error.localizedDescription)",
            )
        }

        try? fileManager.removeItem(at: zipPath)
    }

    private func extractSpecificFolderFromZip(zipPath: URL, destinationPath: URL) throws {
        let fileManager = FileManager.default

        let archive: Archive
        do {
            archive = try Archive(url: zipPath, accessMode: .read)
        } catch {
            throw GlobalError.validation(
                i18nKey: "error.validation.cannot_open_zip",
                level: .notification,
                message: "cannot open zip file: \(zipPath.path), error: \(error.localizedDescription)",
            )
        }

        var targetFolderEntries: [Entry] = []
        var targetFolderPrefix: String?

        for entry in archive {
            let path = entry.path

            let pathComponents = path.split(separator: "/")

            for (index, component) in pathComponents.enumerated() {
                let componentStr = String(component)
                if componentStr.hasPrefix("zulu-"), componentStr.contains(".jre") {
                    if targetFolderPrefix == nil {
                        let prefixComponents = pathComponents[0 ... index]
                        targetFolderPrefix = prefixComponents.joined(separator: "/")
                        if let prefix = targetFolderPrefix, !prefix.isEmpty {
                            targetFolderPrefix = prefix + "/"
                        }
                    }
                    break
                }
            }

            if let prefix = targetFolderPrefix, path.hasPrefix(prefix) {
                targetFolderEntries.append(entry)
            }
        }

        guard !targetFolderEntries.isEmpty, let prefix = targetFolderPrefix else {
            throw GlobalError.validation(
                i18nKey: "error.validation.zulu_folder_not_found_in_zip",
                level: .notification,
                message: "no zulu JRE folder found in zip: \(zipPath.path)",
            )
        }

        for entry in targetFolderEntries {
            let relativePath = String(entry.path.dropFirst(prefix.count))
            let outputPath = destinationPath.appendingPathComponent(relativePath)

            if entry.type == .symlink {
                continue
            }

            do {
                if entry.type == .directory {
                    try fileManager.createDirectory(at: outputPath, withIntermediateDirectories: true)
                } else if entry.type == .file {
                    let parentDir = outputPath.deletingLastPathComponent()
                    try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)

                    _ = try archive.extract(entry, to: outputPath)
                } else {
                    continue
                }
            } catch {
                if let archiveError = error as? Archive.ArchiveError {
                    if String(describing: archiveError) == "uncontainedSymlink" {
                        continue
                    }
                }

                AppLog.game.error("Extraction failed: \(entry.path) - \(error.localizedDescription)")
                throw error
            }
        }
    }

    private func downloadZipWithProgress(from url: URL, to destinationURL: URL, fileName: String) async throws {
        let progressCallback: (Int64, Int64) -> Void = { [progressActor] downloadedBytes, totalBytes in
            Task {
                await progressActor.callProgressUpdate(fileName, Int(downloadedBytes), Int(totalBytes))
            }
        }
        _ = try await ProgressDownloadManager.downloadFile(
            urlString: url.absoluteString,
            destinationURL: destinationURL,
            progressHandler: progressCallback,
        )
    }
}

private actor Counter {
    private var value = 0

    func increment() -> Int {
        value += 1
        return value
    }
}

private actor ProgressActor {
    private var callback: ((String, Int, Int) -> Void)?

    func setCallback(_ callback: @escaping (String, Int, Int) -> Void) {
        self.callback = callback
    }

    func callProgressUpdate(_ fileName: String, _ completed: Int, _ total: Int) {
        callback?(fileName, completed, total)
    }
}

private actor CancelActor {
    private var callback: (() -> Bool)?

    func setCallback(_ callback: @escaping () -> Bool) {
        self.callback = callback
    }

    func shouldCancel() -> Bool {
        callback?() ?? false
    }
}
