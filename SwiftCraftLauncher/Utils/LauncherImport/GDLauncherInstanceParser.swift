//
//  GDLauncherInstanceParser.swift
//  SwiftCraftLauncher
//
//

import Foundation

/// GDLauncher 实例解析器
struct GDLauncherInstanceParser: LauncherInstanceParser {
    let launcherType: ImportLauncherType = .gdLauncher

    func isValidInstance(at instancePath: URL) -> Bool {
        let instanceJsonPath = instancePath.appendingPathComponent("instance.json")
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: instanceJsonPath.path) else {
            return false
        }

        // 验证 JSON 文件可以解析
        do {
            _ = try parseInstanceJson(at: instanceJsonPath)
            return true
        } catch {
            return false
        }
    }

    func parseInstance(at instancePath: URL, basePath: URL) throws -> ImportInstanceInfo? {
        let instanceJsonPath = instancePath.appendingPathComponent("instance.json")
        let instanceConfig = try parseInstanceJson(at: instanceJsonPath)

        // 提取游戏版本
        let gameVersion = instanceConfig.gameConfiguration.version.release

        // 提取 Mod 加载器信息（取第一个 modloader）
        var modLoader = "vanilla"
        var modLoaderVersion = ""

        if let firstModLoader = instanceConfig.gameConfiguration.version.modloaders.first {
            modLoader = firstModLoader.type.lowercased()
            modLoaderVersion = firstModLoader.version
        }

        // 提取游戏名称
        let gameName = instanceConfig.name

        // 提取图标路径
        var gameIconPath: URL?
        if let iconName = instanceConfig.icon {
            let iconPath = instancePath.appendingPathComponent(iconName)
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: iconPath.path) {
                gameIconPath = iconPath
            }
        }

        // 游戏目录可能是 instance 子文件夹，也可能是实例文件夹本身
        let gameDirectory: URL
        let instanceSubfolder = instancePath.appendingPathComponent("instance")
        if FileManager.default.fileExists(atPath: instanceSubfolder.path) {
            gameDirectory = instanceSubfolder
        } else {
            gameDirectory = instancePath
        }

        return ImportInstanceInfo(
            gameName: gameName,
            gameVersion: gameVersion,
            modLoader: modLoader,
            modLoaderVersion: modLoaderVersion,
            gameIconPath: gameIconPath,
            iconDownloadUrl: nil,
            sourceGameDirectory: gameDirectory,
            instanceFolder: instancePath,
            launcherType: launcherType
        )
    }

    // MARK: - Private Methods

    /// 解析 instance.json 文件
    private func parseInstanceJson(at path: URL) throws -> GDLauncherInstanceConfig {
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(GDLauncherInstanceConfig.self, from: data)
    }
}

// MARK: - GDLauncher Models
private struct GDLauncherInstanceConfig: Codable {
    let name: String
    let icon: String?
    let gameConfiguration: GDLauncherGameConfiguration

    enum CodingKeys: String, CodingKey {
        case name
        case icon
        case gameConfiguration = "game_configuration"
    }
}

private struct GDLauncherGameConfiguration: Codable {
    let version: GDLauncherVersion
}

private struct GDLauncherVersion: Codable {
    let release: String
    let modloaders: [GDLauncherModLoader]
}

private struct GDLauncherModLoader: Codable {
    let type: String
    let version: String
}
