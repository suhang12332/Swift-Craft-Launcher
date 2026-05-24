import Foundation

/// GDLauncher 实例解析器
struct GDLauncherInstanceParser: LauncherInstanceParser {
    let launcherType: ImportLauncherType = .gdLauncher

    func isValidInstance(at instancePath: URL) -> Bool {
        do {
            _ = try loadConfig(at: instancePath)
            return true
        } catch {
            return false
        }
    }

    func parseInstance(at instancePath: URL, basePath: URL) throws -> ImportInstanceInfo? {
        let config = try loadConfig(at: instancePath)
        let modLoader = normalizedLoader(from: config.loaderType)
        let gameName = config.sourceName ?? instancePath.lastPathComponent
        let iconPath = resolveIconPath(background: config.background, instancePath: instancePath)

        return ImportInstanceInfo(
            gameName: gameName,
            gameVersion: config.mcVersion,
            modLoader: modLoader,
            modLoaderVersion: config.loaderVersion ?? "",
            gameIconPath: iconPath,
            iconDownloadUrl: nil,
            sourceGameDirectory: resolveSourceGameDirectory(for: instancePath),
            launcherType: launcherType
        )
    }

    private func loadConfig(at instancePath: URL) throws -> GDLauncherConfig {
        let decoder = JSONDecoder()

        for fileName in ["config.json", "instance.json"] {
            let fileURL = instancePath.appendingPathComponent(fileName)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                continue
            }
            let data = try Data(contentsOf: fileURL)
            if let config = try? decoder.decode(GDLauncherConfig.self, from: data) {
                return config
            }
        }

        throw ImportError.fileNotFound(path: instancePath.appendingPathComponent("config.json").path)
    }

    private func normalizedLoader(from loaderType: String?) -> String {
        guard let loaderType else {
            return GameLoader.vanilla.displayName
        }

        switch loaderType.lowercased() {
        case GameLoader.fabric.displayName:
            return GameLoader.fabric.displayName
        case GameLoader.forge.displayName:
            return GameLoader.forge.displayName
        case GameLoader.neoforge.displayName, "neo_forge":
            return GameLoader.neoforge.displayName
        case GameLoader.quilt.rawValue:
            return GameLoader.quilt.rawValue
        default:
            return GameLoader.vanilla.displayName
        }
    }

    private func resolveIconPath(background: String?, instancePath: URL) -> URL? {
        guard let background, !background.isEmpty else {
            return nil
        }

        let iconPath = instancePath.appendingPathComponent(background)
        return FileManager.default.fileExists(atPath: iconPath.path) ? iconPath : nil
    }

    private func resolveSourceGameDirectory(for instancePath: URL) -> URL {
        let fileManager = FileManager.default
        let candidates = [
            instancePath.appendingPathComponent("instance"),
            instancePath.appendingPathComponent(".minecraft"),
            instancePath.appendingPathComponent("minecraft"),
        ]

        for candidate in candidates {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return candidate
            }
        }

        return instancePath
    }
}

private struct GDLauncherConfig: Decodable {
    let background: String?
    let sourceName: String?
    let mcVersion: String
    let loaderType: String?
    let loaderVersion: String?

    private enum CodingKeys: String, CodingKey {
        case background
        case name
        case icon
        case loader
        case loaderType
        case loaderVersion
        case mcVersion
        case sourceName
        case loaderTypeSnake = "loader_type"
        case loaderVersionSnake = "loader_version"
        case mcVersionSnake = "mc_version"
        case sourceNameSnake = "source_name"
        case gameConfiguration = "game_configuration"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        background = try container.decodeIfPresent(String.self, forKey: .background)
        let legacyLoader = try container.decodeIfPresent(GDLauncherLegacyLoader.self, forKey: .loader)
        let modernConfiguration = try container.decodeIfPresent(
            GDLauncherGameConfiguration.self,
            forKey: .gameConfiguration
        )

        sourceName = try container.decodeIfPresent(String.self, forKey: .sourceName)
            ?? container.decodeIfPresent(String.self, forKey: .sourceNameSnake)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? legacyLoader?.sourceName

        if let modernVersion = modernConfiguration?.version {
            mcVersion = modernVersion.release
            loaderType = modernVersion.modloaders.first?.type
            loaderVersion = modernVersion.modloaders.first?.version
            return
        }

        if let legacyLoader {
            mcVersion = legacyLoader.mcVersion
            loaderType = legacyLoader.loaderType
            loaderVersion = legacyLoader.loaderVersion
            return
        }

        loaderType = try container.decodeIfPresent(String.self, forKey: .loaderType)
            ?? container.decodeIfPresent(String.self, forKey: .loaderTypeSnake)
        loaderVersion = try container.decodeIfPresent(String.self, forKey: .loaderVersion)
            ?? container.decodeIfPresent(String.self, forKey: .loaderVersionSnake)
        mcVersion = try container.decodeIfPresent(String.self, forKey: .mcVersion)
            ?? container.decode(String.self, forKey: .mcVersionSnake)
    }
}

private struct GDLauncherLegacyLoader: Decodable {
    let loaderType: String?
    let loaderVersion: String?
    let mcVersion: String
    let sourceName: String?

    enum CodingKeys: String, CodingKey {
        case loaderType
        case loaderVersion
        case mcVersion
        case sourceName
        case loaderTypeSnake = "loader_type"
        case loaderVersionSnake = "loader_version"
        case mcVersionSnake = "mc_version"
        case sourceNameSnake = "source_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        loaderType = try container.decodeIfPresent(String.self, forKey: .loaderType)
            ?? container.decodeIfPresent(String.self, forKey: .loaderTypeSnake)
        loaderVersion = try container.decodeIfPresent(String.self, forKey: .loaderVersion)
            ?? container.decodeIfPresent(String.self, forKey: .loaderVersionSnake)
        mcVersion = try container.decodeIfPresent(String.self, forKey: .mcVersion)
            ?? container.decode(String.self, forKey: .mcVersionSnake)
        sourceName = try container.decodeIfPresent(String.self, forKey: .sourceName)
            ?? container.decodeIfPresent(String.self, forKey: .sourceNameSnake)
    }
}

private struct GDLauncherGameConfiguration: Decodable {
    let version: GDLauncherVersionConfiguration
}

private struct GDLauncherVersionConfiguration: Decodable {
    let release: String
    let modloaders: [GDLauncherModLoader]
}

private struct GDLauncherModLoader: Decodable {
    let type: String
    let version: String
}
