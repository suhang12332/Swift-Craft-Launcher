import Foundation

struct CurseForgeAppInstanceParser: LauncherInstanceParser {
    let launcherType: ImportLauncherType = .curseForgeApp

    func isValidInstance(at instancePath: URL) -> Bool {
        let metadataPath = instancePath.appendingPathComponent("minecraftinstance.json")
        guard FileManager.default.fileExists(atPath: metadataPath.path) else {
            return false
        }

        do {
            _ = try parseMetadata(at: metadataPath)
            return true
        } catch {
            return false
        }
    }

    func parseInstance(at instancePath: URL, basePath: URL) throws -> ImportInstanceInfo? {
        let metadata = try parseMetadata(at: instancePath.appendingPathComponent("minecraftinstance.json"))
        let (modLoader, modLoaderVersion) = extractLoader(from: metadata.baseModLoader?.name)

        return ImportInstanceInfo(
            gameName: metadata.name ?? instancePath.lastPathComponent,
            gameVersion: metadata.gameVersion,
            modLoader: modLoader,
            modLoaderVersion: modLoaderVersion,
            gameIconPath: resolveIconPath(metadata.profileImagePath, instancePath: instancePath),
            iconDownloadUrl: metadata.installedModpack?.thumbnailURL,
            sourceGameDirectory: instancePath,
            launcherType: launcherType
        )
    }

    private func parseMetadata(at path: URL) throws -> CurseForgeInstanceMetadata {
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(CurseForgeInstanceMetadata.self, from: data)
    }

    private func extractLoader(from rawLoader: String?) -> (String, String) {
        guard let rawLoader else {
            return (GameLoader.vanilla.displayName, "")
        }

        let components = rawLoader.split(separator: "-").map(String.init)
        guard let first = components.first else {
            return (GameLoader.vanilla.displayName, "")
        }

        switch first.lowercased() {
        case GameLoader.forge.displayName:
            return (GameLoader.forge.displayName, components.dropFirst().joined(separator: "-"))
        case GameLoader.fabric.displayName:
            return (GameLoader.fabric.displayName, components.dropFirst().first ?? "")
        case GameLoader.quilt.rawValue:
            return (GameLoader.quilt.rawValue, components.dropFirst().first ?? "")
        case GameLoader.neoforge.displayName:
            return (GameLoader.neoforge.displayName, components.dropFirst().joined(separator: "-"))
        default:
            return (GameLoader.vanilla.displayName, "")
        }
    }

    private func resolveIconPath(_ iconPath: String?, instancePath: URL) -> URL? {
        guard let iconPath, !iconPath.isEmpty else {
            return nil
        }

        let absolutePath = URL(fileURLWithPath: iconPath)
        if FileManager.default.fileExists(atPath: absolutePath.path) {
            return absolutePath
        }

        let relativePath = instancePath.appendingPathComponent(iconPath)
        return FileManager.default.fileExists(atPath: relativePath.path) ? relativePath : nil
    }
}

private struct CurseForgeInstanceMetadata: Codable {
    let name: String?
    let baseModLoader: CurseForgeBaseModLoader?
    let profileImagePath: String?
    let installedModpack: CurseForgeInstalledModpack?
    let gameVersion: String

    enum CodingKeys: String, CodingKey {
        case name
        case baseModLoader = "baseModLoader"
        case profileImagePath = "profileImagePath"
        case installedModpack = "installedModpack"
        case gameVersion = "gameVersion"
    }
}

private struct CurseForgeBaseModLoader: Codable {
    let name: String
}

private struct CurseForgeInstalledModpack: Codable {
    let thumbnailURL: String?

    enum CodingKeys: String, CodingKey {
        case thumbnailURL = "thumbnailUrl"
    }
}
