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
        let indexFile: ModrinthIndexFile?
        let curseForgeFile: CurseForgeManifestBuilder.ManifestFile?
        let curseForgeModListItem: CurseForgeModListItem?
        let shouldCopyToOverrides: Bool
        let sourceFile: URL
        let relativePath: String
    }

    /// Creates temporary export directories including overrides subdirectories.
    /// - Returns: A tuple of the temp directory and overrides directory.
    static func prepareDirectories() throws -> (tempDir: URL, overridesDir: URL) {
        let tempDir = try createTempDirectory()
        let overridesDir = tempDir.appendingPathComponent("overrides")
        try FileManager.default.createDirectory(at: overridesDir, withIntermediateDirectories: true)

        for resourceType in ResourceType.allCases {
            let subDir = overridesDir.appendingPathComponent(resourceType.overridesSubdirectory)
            try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        }

        return (tempDir, overridesDir)
    }

    /// Scans selected resources and categorizes them by export format.
    static func identifySelectedResources(
        gameInfo: GameVersionInfo,
        selectedFiles: [URL],
        totalResources: Int,
        exportFormat: ModPackExportFormat,
        progressUpdater: ProgressUpdater,
        progressCallback: ((ExportProgress) -> Void)?,
    ) async -> SelectedResourcesResult {
        var indexFiles: [ModrinthIndexFile] = []
        var curseForgeFiles: [CurseForgeManifestBuilder.ManifestFile] = []
        var curseForgeModListItems: [CurseForgeModListItem] = []
        var filesToCopy: [(file: URL, relativePath: String)] = []

        let gameDirectory = AppPaths.profileDirectory(gameName: gameInfo.gameName)
        let processedCounter = ProcessedCounter()

        let shouldScan: (URL) -> Bool = switch exportFormat {
        case .modrinth:
            { shouldScanForModrinth($0, gameDirectory: gameDirectory) }
        case .curseforge:
            { shouldScanForCurseForge($0, gameDirectory: gameDirectory) }
        }

        for file in selectedFiles where !shouldScan(file) {
            if Task.isCancelled { break }
            let relativePath = makeRelativePath(for: file, gameDirectory: gameDirectory)
            filesToCopy.append((file: file, relativePath: relativePath))
        }

        return await withTaskGroup(of: SelectedResourceProcessResult.self) { group in
            for file in selectedFiles where shouldScan(file) {
                group.addTask {
                    let relativePath = inferOverridesSubdirectory(for: file, gameDirectory: gameDirectory)
                    if Task.isCancelled {
                        return SelectedResourceProcessResult(
                            indexFile: nil,
                            curseForgeFile: nil,
                            curseForgeModListItem: nil,
                            shouldCopyToOverrides: false,
                            sourceFile: file,
                            relativePath: relativePath,
                        )
                    }
                    let result = await identifyResourceByFormat(
                        file: file,
                        relativePath: relativePath,
                        gameDirectory: gameDirectory,
                        exportFormat: exportFormat,
                    )

                    let processed = await processedCounter.increment()
                    let scanTotal = max(totalResources, 1)
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
                if let indexFile = result.indexFile {
                    indexFiles.append(indexFile)
                }
                if let curseForgeFile = result.curseForgeFile {
                    curseForgeFiles.append(curseForgeFile)
                    if let modListItem = result.curseForgeModListItem {
                        curseForgeModListItems.append(modListItem)
                    }
                } else if result.shouldCopyToOverrides {
                    filesToCopy.append((file: result.sourceFile, relativePath: result.relativePath))
                }
            }

            return SelectedResourcesResult(
                indexFiles: indexFiles,
                curseForgeFiles: curseForgeFiles,
                curseForgeModListItems: curseForgeModListItems,
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

    static func inferOverridesSubdirectory(for file: URL, gameDirectory: URL) -> String {
        guard let topLevel = topLevelDirectoryName(of: file, gameDirectory: gameDirectory) else {
            return makeRelativePath(for: file, gameDirectory: gameDirectory)
        }

        let lowercasedTopLevel = topLevel.lowercased()

        if lowercasedTopLevel == AppConstants.DirectoryNames.datapacks.lowercased() {
            return AppConstants.DirectoryNames.datapacks
        }
        if lowercasedTopLevel == AppConstants.DirectoryNames.shaderpacks.lowercased() {
            return AppConstants.DirectoryNames.shaderpacks
        }
        if lowercasedTopLevel == AppConstants.DirectoryNames.resourcepacks.lowercased() {
            return AppConstants.DirectoryNames.resourcepacks
        }
        if lowercasedTopLevel == AppConstants.DirectoryNames.mods.lowercased() {
            return AppConstants.DirectoryNames.mods
        }

        return makeRelativePath(for: file, gameDirectory: gameDirectory)
    }

    static func topLevelDirectoryName(of file: URL, gameDirectory: URL) -> String? {
        let filePath = file.standardizedFileURL.path
        let rootPath = gameDirectory.standardizedFileURL.path

        guard filePath.hasPrefix(rootPath) else {
            return nil
        }

        let relative = String(filePath.dropFirst(rootPath.count))
        let trimmed = relative.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else {
            return nil
        }

        if let firstSlash = trimmed.firstIndex(of: "/") {
            return String(trimmed[..<firstSlash])
        } else {
            return trimmed
        }
    }

    static func shouldScanForModrinth(_ file: URL, gameDirectory: URL) -> Bool {
        guard let topLevel = topLevelDirectoryName(of: file, gameDirectory: gameDirectory)?.lowercased() else {
            return false
        }

        return topLevel == AppConstants.DirectoryNames.datapacks.lowercased()
            || topLevel == AppConstants.DirectoryNames.shaderpacks.lowercased()
            || topLevel == AppConstants.DirectoryNames.resourcepacks.lowercased()
            || topLevel == AppConstants.DirectoryNames.mods.lowercased()
    }

    static func shouldScanForCurseForge(_ file: URL, gameDirectory: URL) -> Bool {
        guard let topLevel = topLevelDirectoryName(of: file, gameDirectory: gameDirectory)?.lowercased() else {
            return false
        }
        return topLevel == AppConstants.DirectoryNames.mods.lowercased()
            && file.pathExtension.lowercased() == AppConstants.FileExtensions.jar
    }

    static func makeRelativePath(for file: URL, gameDirectory: URL) -> String {
        let filePath = file.standardizedFileURL.path
        let rootPath = gameDirectory.standardizedFileURL.path

        if filePath.hasPrefix(rootPath) {
            let relative = String(filePath.dropFirst(rootPath.count))
            let trimmed = relative.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if let lastSlash = trimmed.lastIndex(of: "/") {
                return String(trimmed[..<lastSlash])
            } else {
                return ""
            }
        } else {
            return ""
        }
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
