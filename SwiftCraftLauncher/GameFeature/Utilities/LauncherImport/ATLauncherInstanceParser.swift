import Foundation

struct ATLauncherInstanceParser: LauncherInstanceParser {
    let launcherType: ImportLauncherType = .atLauncher

    func isValidInstance(at instancePath: URL) -> Bool {
        let instanceJSON = instancePath.appendingPathComponent("instance.json")
        guard FileManager.default.fileExists(atPath: instanceJSON.path) else {
            return false
        }

        do {
            _ = try parseInstanceJSON(at: instanceJSON)
            return true
        } catch {
            return false
        }
    }

    func parseInstance(at instancePath: URL, basePath: URL) throws -> ImportInstanceInfo? {
        let instance = try parseInstanceJSON(at: instancePath.appendingPathComponent("instance.json"))
        let modLoader = normalizedLoader(from: instance.launcher.loaderVersion.type)

        return ImportInstanceInfo(
            gameName: instance.launcher.name,
            gameVersion: instance.id,
            modLoader: modLoader,
            modLoaderVersion: instance.launcher.loaderVersion.version,
            gameIconPath: resolveIconPath(instance: instance, instancePath: instancePath, basePath: basePath),
            iconDownloadUrl: nil,
            sourceGameDirectory: instancePath,
            launcherType: launcherType
        )
    }

    private func parseInstanceJSON(at path: URL) throws -> ATLauncherInstance {
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(ATLauncherInstance.self, from: data)
    }

    private func normalizedLoader(from rawLoader: String) -> String {
        switch rawLoader.lowercased() {
        case GameLoader.fabric.displayName:
            return GameLoader.fabric.displayName
        case GameLoader.forge.displayName:
            return GameLoader.forge.displayName
        case GameLoader.neoforge.displayName:
            return GameLoader.neoforge.displayName
        case GameLoader.quilt.rawValue:
            return GameLoader.quilt.rawValue
        default:
            return GameLoader.vanilla.displayName
        }
    }

    private func resolveIconPath(
        instance: ATLauncherInstance,
        instancePath: URL,
        basePath: URL
    ) -> URL? {
        let fileManager = FileManager.default
        let primaryPath = instancePath.appendingPathComponent("instance.png")
        if fileManager.fileExists(atPath: primaryPath.path) {
            return primaryPath
        }

        let safePackName = instance.launcher.pack
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
        guard !safePackName.isEmpty else {
            return nil
        }

        let secondaryPath = basePath
            .appendingPathComponent("configs")
            .appendingPathComponent("images")
            .appendingPathComponent("\(safePackName).png")
        return fileManager.fileExists(atPath: secondaryPath.path) ? secondaryPath : nil
    }
}

private struct ATLauncherInstance: Codable {
    let id: String
    let launcher: ATLauncherMetadata
}

private struct ATLauncherMetadata: Codable {
    let name: String
    let pack: String
    let loaderVersion: ATLauncherLoaderVersion
}

private struct ATLauncherLoaderVersion: Codable {
    let type: String
    let version: String
}
