import Foundation

extension ModPackExporter {
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
