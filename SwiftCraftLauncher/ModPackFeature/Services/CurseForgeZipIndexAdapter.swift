import Foundation

struct CurseForgeZipIndexAdapter: ModPackIndexAdapter {
    let id: String = "curseforge"

    func canParse(extractedPath: URL) async -> Bool {
        let manifestPath = extractedPath.appendingPathComponent("manifest.json")
        return await Task.detached(priority: .userInitiated) {
            FileManager.default.fileExists(atPath: manifestPath.path)
        }.value
    }

    func parseToModrinthIndexInfo(extractedPath: URL) async -> ModrinthIndexInfo? {
        await CurseForgeManifestParser.parseManifest(extractedPath: extractedPath)
    }
}
