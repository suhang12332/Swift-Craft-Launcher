import Foundation

extension ModPackExporter {
    static func identifyCurseForgeResource(
        file: URL,
        relativePath: String,
        gameDirectory: URL
    ) async -> SelectedResourceProcessResult {
        if Task.isCancelled {
            return SelectedResourceProcessResult(
                indexFile: nil,
                curseForgeFile: nil,
                curseForgeModListItem: nil,
                shouldCopyToOverrides: false,
                sourceFile: file,
                relativePath: relativePath
            )
        }
        guard isModsJarFile(file, gameDirectory: gameDirectory) else {
            return SelectedResourceProcessResult(
                indexFile: nil,
                curseForgeFile: nil,
                curseForgeModListItem: nil,
                shouldCopyToOverrides: true,
                sourceFile: file,
                relativePath: relativePath
            )
        }

        if Task.isCancelled {
            return SelectedResourceProcessResult(
                indexFile: nil,
                curseForgeFile: nil,
                curseForgeModListItem: nil,
                shouldCopyToOverrides: false,
                sourceFile: file,
                relativePath: relativePath
            )
        }
        guard let fingerprint = try? CurseForgeFingerprint.fingerprint(fileAt: file),
              let match = await CurseForgeService.fetchProjectAndFileByFingerprint(fingerprint: fingerprint) else {
            return SelectedResourceProcessResult(
                indexFile: nil,
                curseForgeFile: nil,
                curseForgeModListItem: nil,
                shouldCopyToOverrides: true,
                sourceFile: file,
                relativePath: relativePath
            )
        }

        return SelectedResourceProcessResult(
            indexFile: nil,
            curseForgeFile: CurseForgeManifestBuilder.ManifestFile(
                projectID: match.projectId,
                fileID: match.fileId,
                required: true,
                isLocked: false
            ),
            curseForgeModListItem: CurseForgeModListItem(
                projectID: match.projectId,
                fileID: match.fileId,
                fileName: file.lastPathComponent,
                projectName: nil,
                authorsText: nil
            ),
            shouldCopyToOverrides: false,
            sourceFile: file,
            relativePath: relativePath
        )
    }

    static func writeCurseForgeManifest(
        params: IndexBuildParams,
        tempDir: URL
    ) async throws -> [String] {
        let manifestJson = try CurseForgeManifestBuilder.build(
            gameInfo: params.gameInfo,
            modPackName: params.modPackName,
            modPackVersion: params.modPackVersion,
            files: params.curseForgeFiles
        )
        let manifestFileName = "manifest.json"
        let manifestPath = tempDir.appendingPathComponent(manifestFileName)
        try manifestJson.write(to: manifestPath, atomically: true, encoding: .utf8)
        let modListFileName = "modlist.html"
        let modListPath = tempDir.appendingPathComponent(modListFileName)
        let modListHTML = buildCurseForgeModListHTML(items: params.curseForgeModListItems)
        try modListHTML.write(to: modListPath, atomically: true, encoding: .utf8)
        return [manifestFileName, modListFileName]
    }

    private static func isModsJarFile(_ file: URL, gameDirectory: URL) -> Bool {
        let topLevel = topLevelDirectoryName(of: file, gameDirectory: gameDirectory)?.lowercased()
        return topLevel == AppConstants.DirectoryNames.mods.lowercased() &&
            file.pathExtension.lowercased() == AppConstants.FileExtensions.jar
    }

    private static func buildCurseForgeModListHTML(items: [CurseForgeModListItem]) -> String {
        let modProjectBaseURL = URLConfig.API.CurseForge.webProjectURL(projectType: ResourceType.mod.rawValue)
        let listItems = items
            .sorted { displayTitle(for: $0).localizedCaseInsensitiveCompare(displayTitle(for: $1)) == .orderedAscending }
            .map { item in
                let title = displayTitle(for: item)
                let bySuffix = item.authorsText.map { " (by \($0))" } ?? ""
                return """
                <li><a href="\(modProjectBaseURL)\(item.projectID)">\(escapeHTML(title))\(escapeHTML(bySuffix))</a></li>
                """
            }
            .joined(separator: "\n")

        return listItems.isEmpty ? "" : "<ul>\n\(listItems)\n</ul>"
    }

    private static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func displayTitle(for item: CurseForgeModListItem) -> String {
        if let projectName = item.projectName, !projectName.isEmpty {
            return projectName
        }
        return item.fileName
    }
}
