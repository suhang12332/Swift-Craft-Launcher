//
//  ModPackExporter+Curseforge.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension ModPackExporter {
    /// Identifies a resource for inclusion in a CurseForge-format mod pack.
    ///
    /// Performs fingerprint-based lookup against the CurseForge API for
    /// `.jar` / `.zip` files in the four export resource folders.
    /// Unmatched resources are copied to overrides.
    ///
    /// - Parameters:
    ///   - file: The file to identify.
    ///   - relativePath: The path relative to the game directory.
    ///   - gameDirectory: The root directory of the game instance.
    /// - Returns: A result describing how the resource should be processed.
    static func identifyCurseForgeResource(
        file: URL,
        relativePath: String,
        gameDirectory: URL,
    ) async -> SelectedResourceProcessResult {
        if Task.isCancelled {
            return SelectedResourceProcessResult(
                sourceFile: file,
                relativePath: relativePath,
                outcome: .cancelled,
            )
        }
        guard shouldScanResource(file, gameDirectory: gameDirectory) else {
            return SelectedResourceProcessResult(
                sourceFile: file,
                relativePath: relativePath,
                outcome: .copy,
            )
        }

        guard let fingerprint = try? CurseForgeFingerprint.fingerprint(fileAt: file),
              let match = try? await CurseForgeService.fetchProjectAndFileByFingerprintThrowing(fingerprint: fingerprint) else {
            return SelectedResourceProcessResult(
                sourceFile: file,
                relativePath: relativePath,
                outcome: .copy,
            )
        }

        return SelectedResourceProcessResult(
            sourceFile: file,
            relativePath: relativePath,
            outcome: .curseForge(
                file: CurseForgeManifestBuilder.ManifestFile(
                    projectID: match.projectId,
                    fileID: match.fileId,
                    required: true,
                    isLocked: false,
                ),
                listItem: CurseForgeModListItem(
                    projectID: match.projectId,
                    fileName: file.lastPathComponent,
                ),
            ),
        )
    }

    /// Writes the CurseForge manifest and mod list HTML to the temporary export directory.
    ///
    /// - Parameters:
    ///   - params: The parameters used to build the manifest.
    ///   - files: The manifest files.
    ///   - modListItems: The items used to build `modlist.html`.
    ///   - tempDir: The temporary directory for the export.
    /// - Returns: The list of filenames written to the temporary directory.
    static func writeCurseForgeManifest(
        params: IndexBuildParams,
        files: [CurseForgeManifestBuilder.ManifestFile],
        modListItems: [CurseForgeModListItem],
        tempDir: URL,
    ) async throws -> [String] {
        let manifestJson = try CurseForgeManifestBuilder.build(
            gameInfo: params.gameInfo,
            modPackName: params.modPackName,
            modPackVersion: params.modPackVersion,
            files: files,
        )
        let manifestFileName = "manifest.json"
        let manifestPath = tempDir.appendingPathComponent(manifestFileName)
        try manifestJson.write(to: manifestPath, atomically: true, encoding: .utf8)
        let modListFileName = "modlist.html"
        let modListPath = tempDir.appendingPathComponent(modListFileName)
        let modListHTML = buildCurseForgeModListHTML(items: modListItems)
        try modListHTML.write(to: modListPath, atomically: true, encoding: .utf8)
        return [manifestFileName, modListFileName]
    }

    /// Builds an HTML list of matched files for the CurseForge mod list file.
    private static func buildCurseForgeModListHTML(items: [CurseForgeModListItem]) -> String {
        let modProjectBaseURL = URLConfig.API.CurseForge.webProjectURL(projectType: ResourceType.mod.rawValue)
        let listItems = items
            .sorted { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
            .map { item in
                """
                <li><a href="\(modProjectBaseURL)\(item.projectID)">\(escapeHTML(item.fileName))</a></li>
                """
            }
            .joined(separator: "\n")

        return listItems.isEmpty ? "" : "<ul>\n\(listItems)\n</ul>"
    }

    /// Escapes special characters for safe HTML embedding.
    private static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
