//
//  ModPackExporter+Modrinth.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension ModPackExporter {
    /// Identifies a resource for inclusion in a Modrinth-format mod pack.
    ///
    /// - Parameters:
    ///   - file: The file to identify.
    ///   - relativePath: The path relative to the game directory.
    /// - Returns: A result describing how the resource should be processed.
    static func identifyModrinthResource(
        file: URL,
        relativePath: String
    ) async -> SelectedResourceProcessResult {
        let result = await ResourceProcessor.identify(file: file, relativePath: relativePath)
        return SelectedResourceProcessResult(
            indexFile: result.indexFile,
            curseForgeFile: nil,
            curseForgeModListItem: nil,
            shouldCopyToOverrides: result.shouldCopyToOverrides,
            sourceFile: result.sourceFile,
            relativePath: result.relativePath
        )
    }

    /// Writes the Modrinth index manifest to the temporary export directory.
    ///
    /// - Parameters:
    ///   - params: The parameters used to build the index.
    ///   - tempDir: The temporary directory for the export.
    /// - Returns: The list of filenames written to the temporary directory.
    static func writeModrinthManifest(
        params: IndexBuildParams,
        tempDir: URL
    ) async throws -> [String] {
        let indexJson = try await ModrinthIndexBuilder.build(
            gameInfo: params.gameInfo,
            modPackName: params.modPackName,
            modPackVersion: params.modPackVersion,
            summary: params.summary,
            files: params.indexFiles
        )

        let indexPath = tempDir.appendingPathComponent(AppConstants.modrinthIndexFileName)
        try indexJson.write(to: indexPath, atomically: true, encoding: String.Encoding.utf8)
        return [AppConstants.modrinthIndexFileName]
    }
}
