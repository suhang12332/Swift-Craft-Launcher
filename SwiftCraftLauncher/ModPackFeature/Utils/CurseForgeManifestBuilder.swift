import Foundation

enum CurseForgeManifestBuilder {
    struct ManifestFile: Codable {
        let projectID: Int
        let fileID: Int
        let required: Bool
        let isLocked: Bool
    }

    private struct Manifest: Codable {
        let minecraft: Minecraft
        let manifestType: String
        let manifestVersion: Int
        let name: String
        let version: String
        let author: String
        let files: [ManifestFile]
        let overrides: String
    }

    private struct Minecraft: Codable {
        let version: String
        let modLoaders: [ModLoader]
    }

    private struct ModLoader: Codable {
        let id: String
        let primary: Bool
    }

    static func build(
        gameInfo: GameVersionInfo,
        modPackName: String,
        modPackVersion: String,
        files: [ManifestFile]
    ) throws -> String {
        let minecraft = Minecraft(
            version: gameInfo.gameVersion,
            modLoaders: buildModLoaders(gameInfo: gameInfo)
        )

        let manifest = Manifest(
            minecraft: minecraft,
            manifestType: "minecraftModpack",
            manifestVersion: 1,
            name: modPackName,
            version: modPackVersion,
            author: "",
            files: files,
            overrides: "overrides"
        )

        let data = try JSONEncoder.prettySorted.encode(manifest)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func buildModLoaders(gameInfo: GameVersionInfo) -> [ModLoader] {
        let loaderType = gameInfo.modLoader.lowercased()
        guard loaderType != GameLoader.vanilla.displayName else { return [] }

        let loaderVersion = gameInfo.modVersion
        if !loaderVersion.isEmpty {
            return [ModLoader(id: "\(loaderType)-\(loaderVersion)", primary: true)]
        }
        return [ModLoader(id: loaderType, primary: true)]
    }
}

private extension JSONEncoder {
    static var prettySorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
