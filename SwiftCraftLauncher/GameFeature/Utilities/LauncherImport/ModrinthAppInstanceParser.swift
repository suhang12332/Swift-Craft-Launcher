import Foundation
import SQLite3

struct ModrinthAppInstanceParser: LauncherInstanceParser {
    let launcherType: ImportLauncherType = .modrinthApp

    func isValidInstance(at instancePath: URL) -> Bool {
        let profileJSON = instancePath.appendingPathComponent("profile.json")
        if FileManager.default.fileExists(atPath: profileJSON.path) {
            do {
                _ = try parseLegacyProfileJSON(at: profileJSON)
                return true
            } catch {
                return false
            }
        }

        return true
    }

    func parseInstance(at instancePath: URL, basePath: URL) throws -> ImportInstanceInfo? {
        if let dbProfile = try parseProfileFromDatabase(
            at: instancePath,
            basePath: basePath
        ) {
            return dbProfile
        }

        let legacyProfile = try parseLegacyProfileJSON(
            at: instancePath.appendingPathComponent("profile.json")
        )
        let metadata = legacyProfile.metadata

        return ImportInstanceInfo(
            gameName: metadata.name,
            gameVersion: metadata.gameVersion,
            modLoader: metadata.loader.rawValue,
            modLoaderVersion: metadata.loaderVersion?.id ?? "",
            gameIconPath: resolveIconPath(icon: metadata.icon, instancePath: instancePath),
            iconDownloadUrl: nil,
            sourceGameDirectory: instancePath,
            launcherType: launcherType
        )
    }

    private func parseProfileFromDatabase(
        at instancePath: URL,
        basePath: URL
    ) throws -> ImportInstanceInfo? {
        let databaseURL = resolveDatabaseURL(from: basePath)
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return nil
        }

        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(
            databaseURL.path,
            &database,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard openResult == SQLITE_OK, let database else {
            if let database {
                sqlite3_close(database)
            }
            return nil
        }
        defer { sqlite3_close(database) }

        let sql = """
        SELECT name, game_version, mod_loader, mod_loader_version, icon_path
        FROM profiles
        WHERE path = ?
        LIMIT 1;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            sqlite3_finalize(statement)
            return nil
        }
        defer { sqlite3_finalize(statement) }

        let relativePath = instancePath.lastPathComponent
        sqlite3_bind_text(statement, 1, relativePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        guard let gameName = sqliteString(from: statement, index: 0),
              let gameVersion = sqliteString(from: statement, index: 1),
              let modLoader = sqliteString(from: statement, index: 2) else {
            return nil
        }

        let modLoaderVersion = sqliteString(from: statement, index: 3) ?? ""
        let iconPathString = sqliteString(from: statement, index: 4)

        return ImportInstanceInfo(
            gameName: gameName,
            gameVersion: gameVersion,
            modLoader: normalizedLoader(modLoader),
            modLoaderVersion: modLoaderVersion,
            gameIconPath: resolveAbsoluteIconPath(iconPathString),
            iconDownloadUrl: nil,
            sourceGameDirectory: instancePath,
            launcherType: launcherType
        )
    }

    private func resolveDatabaseURL(from basePath: URL) -> URL {
        if basePath.lastPathComponent == "profiles" {
            return basePath.deletingLastPathComponent().appendingPathComponent("app.db")
        }
        return basePath.appendingPathComponent("app.db")
    }

    private func parseLegacyProfileJSON(at path: URL) throws -> LegacyModrinthProfile {
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(LegacyModrinthProfile.self, from: data)
    }

    private func resolveIconPath(icon: String?, instancePath: URL) -> URL? {
        guard let icon, !icon.isEmpty else {
            return nil
        }

        let iconPath = instancePath.appendingPathComponent(icon)
        return FileManager.default.fileExists(atPath: iconPath.path) ? iconPath : nil
    }

    private func resolveAbsoluteIconPath(_ iconPath: String?) -> URL? {
        guard let iconPath, !iconPath.isEmpty else {
            return nil
        }

        let iconURL = URL(fileURLWithPath: iconPath)
        return FileManager.default.fileExists(atPath: iconURL.path) ? iconURL : nil
    }

    private func normalizedLoader(_ loader: String) -> String {
        switch loader.lowercased() {
        case GameLoader.fabric.displayName:
            return GameLoader.fabric.displayName
        case GameLoader.forge.displayName:
            return GameLoader.forge.displayName
        case GameLoader.quilt.rawValue:
            return GameLoader.quilt.rawValue
        case GameLoader.neoforge.displayName, "neo_forge":
            return GameLoader.neoforge.displayName
        default:
            return GameLoader.vanilla.displayName
        }
    }

    private func sqliteString(from statement: OpaquePointer, index: Int32) -> String? {
        guard let text = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: text)
    }
}

private struct LegacyModrinthProfile: Codable {
    let metadata: LegacyModrinthProfileMetadata
}

private struct LegacyModrinthProfileMetadata: Codable {
    let name: String
    let icon: String?
    let gameVersion: String
    let loader: ImportedLegacyModrinthLoader
    let loaderVersion: ImportedLegacyModrinthLoaderVersion?

    enum CodingKeys: String, CodingKey {
        case name
        case icon
        case gameVersion = "game_version"
        case loader
        case loaderVersion = "loader_version"
    }
}

private struct ImportedLegacyModrinthLoaderVersion: Codable {
    let id: String
}

private enum ImportedLegacyModrinthLoader: String, Codable {
    case vanilla
    case fabric
    case forge
    case quilt
    case neoforge = "neoforge"
}
