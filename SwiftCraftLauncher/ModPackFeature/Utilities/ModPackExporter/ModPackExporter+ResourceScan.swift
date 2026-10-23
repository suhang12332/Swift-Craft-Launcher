//
//  ModPackExporter+ResourceScan.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension ModPackExporter {
    /// The result of processing a single selected resource during export.
    struct SelectedResourceProcessResult {
        enum Outcome {
            case indexed(ModrinthIndexFile)
            case curseForge(file: CurseForgeManifestBuilder.ManifestFile, listItem: CurseForgeModListItem)
            case copy
            case cancelled
        }

        let sourceFile: URL
        let relativePath: String
        let outcome: Outcome
    }

    /// Creates the temporary export directory and its overrides root.
    /// - Returns: A tuple of the temp directory and overrides directory.
    static func prepareDirectories() throws -> (tempDir: URL, overridesDir: URL) {
        let tempDir = try createTempDirectory()
        let overridesDir = tempDir.appendingPathComponent("overrides")
        try FileManager.default.createDirectory(at: overridesDir, withIntermediateDirectories: true)
        return (tempDir, overridesDir)
    }

    /// Scans selected resources and categorizes them by export format.
    static func identifySelectedResources(
        gameDirectory: URL,
        filesToScan: [URL],
        filesOutsideScanScope: [URL],
        exportFormat: ModPackExportFormat,
        progressUpdater: ProgressUpdater,
        progressCallback: (@Sendable (ExportProgress) -> Void)?,
    ) async -> SelectedResourcesResult {
        var indexFiles: [ModrinthIndexFile] = []
        var curseForgeFiles: [CurseForgeManifestBuilder.ManifestFile] = []
        var curseForgeModListItems: [CurseForgeModListItem] = []
        // Starts with files outside the four scanned folders; scanned files that
        // cannot be identified are appended below, so the copy total is exactly
        // "other files + scan failures".
        var filesToCopy: [(file: URL, relativePath: String)] = []

        let processedCounter = ProcessedCounter()
        let scanTotal = max(filesToScan.count, 1)

        for file in filesOutsideScanScope {
            if Task.isCancelled {
                break
            }
            let relativePath = makeRelativePath(for: file, gameDirectory: gameDirectory)
            filesToCopy.append((file: file, relativePath: relativePath))
        }

        return await withTaskGroup(of: SelectedResourceProcessResult.self) { group in
            let semaphore = AsyncSemaphore(value: maxConcurrentExportOperations)

            for file in filesToScan {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }

                    let relativePath = makeRelativePath(for: file, gameDirectory: gameDirectory)
                    if Task.isCancelled {
                        return SelectedResourceProcessResult(
                            sourceFile: file,
                            relativePath: relativePath,
                            outcome: .cancelled,
                        )
                    }
                    let result = await identifyResourceByFormat(
                        file: file,
                        relativePath: relativePath,
                        gameDirectory: gameDirectory,
                        exportFormat: exportFormat,
                    )

                    let processed = await processedCounter.increment()
                    let updatedProgress = await progressUpdater.advanceScanProgress(
                        processed: processed,
                        total: scanTotal,
                        currentFile: result.sourceFile.lastPathComponent,
                    )
                    progressCallback?(updatedProgress)

                    return result
                }
            }

            for await result in group {
                switch result.outcome {
                case let .indexed(indexFile):
                    indexFiles.append(indexFile)
                case let .curseForge(file, listItem):
                    curseForgeFiles.append(file)
                    curseForgeModListItems.append(listItem)
                case .copy:
                    filesToCopy.append((file: result.sourceFile, relativePath: result.relativePath))
                case .cancelled:
                    break
                }
            }

            let manifest: ModPackManifestData = switch exportFormat {
            case .modrinth:
                .modrinth(indexFiles)
            case .curseforge:
                .curseForge(files: curseForgeFiles, modListItems: curseForgeModListItems)
            }

            return SelectedResourcesResult(
                manifest: manifest,
                filesToCopy: filesToCopy,
            )
        }
    }

    static func identifyResourceByFormat(
        file: URL,
        relativePath: String,
        gameDirectory: URL,
        exportFormat: ModPackExportFormat,
    ) async -> SelectedResourceProcessResult {
        switch exportFormat {
        case .modrinth:
            return await identifyModrinthResource(file: file, relativePath: relativePath)
        case .curseforge:
            return await identifyCurseForgeResource(
                file: file,
                relativePath: relativePath,
                gameDirectory: gameDirectory,
            )
        }
    }

    static func topLevelDirectoryName(of file: URL, gameDirectory: URL) -> String? {
        guard let relativePath = normalizedRelativePath(of: file, gameDirectory: gameDirectory) else {
            return nil
        }

        if let firstSlash = relativePath.firstIndex(of: "/") {
            return String(relativePath[..<firstSlash])
        }
        return relativePath
    }

    static func shouldScanResource(_ file: URL, gameDirectory: URL) -> Bool {
        guard let topLevel = topLevelDirectoryName(of: file, gameDirectory: gameDirectory)?.lowercased() else {
            return false
        }

        let fileExtension = file.pathExtension.lowercased()
        guard fileExtension == AppConstants.FileExtensions.jar
            || fileExtension == AppConstants.FileExtensions.zip
        else {
            return false
        }

        return topLevel == AppConstants.DirectoryNames.datapacks.lowercased()
            || topLevel == AppConstants.DirectoryNames.shaderpacks.lowercased()
            || topLevel == AppConstants.DirectoryNames.resourcepacks.lowercased()
            || topLevel == AppConstants.DirectoryNames.mods.lowercased()
    }

    static func makeRelativePath(for file: URL, gameDirectory: URL) -> String {
        guard let relativePath = normalizedRelativePath(of: file, gameDirectory: gameDirectory) else {
            return ""
        }

        if let lastSlash = relativePath.lastIndex(of: "/") {
            return String(relativePath[..<lastSlash])
        }
        return ""
    }

    private static func normalizedRelativePath(of file: URL, gameDirectory: URL) -> String? {
        let filePath = file.standardizedFileURL.path
        let rootPath = gameDirectory.standardizedFileURL.path

        guard filePath.hasPrefix(rootPath) else {
            return nil
        }

        let relative = String(filePath.dropFirst(rootPath.count))
        let trimmed = relative.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed.isEmpty ? nil : trimmed
    }

    static func resolveSelectedFiles(from urls: [URL]) -> [URL] {
        guard !urls.isEmpty else { return [] }

        let fm = FileManager.default
        var result: [URL] = []

        for url in urls {
            var isDirectory: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                if let enumerator = fm.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles],
                ) {
                    for case let fileURL as URL in enumerator {
                        if let isRegularFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                           isRegularFile == true {
                            result.append(fileURL)
                        }
                    }
                }
            } else {
                result.append(url)
            }
        }

        return result
    }
}
