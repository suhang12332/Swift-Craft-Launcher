//
//  MultiMCInstanceParser.swift
//  SwiftCraftLauncher
//
//

import Foundation

/// MultiMC/PrismLauncher 实例解析器
struct MultiMCInstanceParser: LauncherInstanceParser {
    let launcherType: ImportLauncherType

    func isValidInstance(at instancePath: URL) -> Bool {
        let instanceCfgPath = instancePath.appendingPathComponent("instance.cfg")
        let mmcPackPath = instancePath.appendingPathComponent("mmc-pack.json")

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: instanceCfgPath.path),
              fileManager.fileExists(atPath: mmcPackPath.path) else {
            return false
        }

        // 验证文件可以解析
        do {
            _ = try parseInstanceCfg(at: instanceCfgPath)
            _ = try parseMMCPack(at: mmcPackPath)
            return true
        } catch {
            return false
        }
    }

    func parseInstance(at instancePath: URL, basePath: URL) throws -> ImportInstanceInfo? {
        let instanceCfgPath = instancePath.appendingPathComponent("instance.cfg")
        let mmcPackPath = instancePath.appendingPathComponent("mmc-pack.json")

        // 解析配置文件
        let instanceCfg = try parseInstanceCfg(at: instanceCfgPath)
        let mmcPack = try parseMMCPack(at: mmcPackPath)

        // 提取游戏版本
        let gameVersion = extractGameVersion(from: mmcPack)

        // 提取 Mod 加载器信息
        let (modLoader, modLoaderVersion) = extractModLoader(from: mmcPack)

        // 提取游戏名称
        let gameName = instanceCfg["name"] ?? instancePath.lastPathComponent

        // 查找 .minecraft 文件夹
        let gameDirectory = findGameDirectory(at: instancePath)
        guard let gameDirectory = gameDirectory else {
            throw ImportError.gameDirectoryNotFound(instancePath: instancePath.path)
        }

        return ImportInstanceInfo(
            gameName: gameName,
            gameVersion: gameVersion,
            modLoader: modLoader,
            modLoaderVersion: modLoaderVersion,
            gameIconPath: nil,
            iconDownloadUrl: nil,
            sourceGameDirectory: gameDirectory,
            instanceFolder: instancePath,
            launcherType: launcherType
        )
    }

    // MARK: - Private Methods

    /// 解析 instance.cfg 文件（INI 格式）
    private func parseInstanceCfg(at path: URL) throws -> [String: String] {
        let content = try String(contentsOf: path, encoding: .utf8)
        var config: [String: String] = [:]

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            if let equalIndex = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[..<equalIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                let value = String(trimmed[trimmed.index(after: equalIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                config[key] = value
            }
        }

        return config
    }

    /// 解析 mmc-pack.json 文件
    private func parseMMCPack(at path: URL) throws -> MMCPack {
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(MMCPack.self, from: data)
    }

    /// 从 mmc-pack.json 提取游戏版本
    private func extractGameVersion(from pack: MMCPack) -> String {
        for component in pack.components where component.uid == "net.minecraft" {
            return component.version
        }
        return ""
    }

    /// 从 mmc-pack.json 提取 Mod 加载器信息
    private func extractModLoader(from pack: MMCPack) -> (loader: String, version: String) {
        for component in pack.components {
            switch component.uid {
            case "net.fabricmc.fabric-loader":
                return ("fabric", component.version)
            case "net.minecraftforge":
                return ("forge", component.version)
            case "net.neoforged":
                return ("neoforge", component.version)
            case "org.quiltmc.quilt-loader":
                return ("quilt", component.version)
            default:
                continue
            }
        }
        return ("vanilla", "")
    }

    /// 查找 .minecraft 文件夹
    private func findGameDirectory(at instancePath: URL) -> URL? {
        let fileManager = FileManager.default

        // 优先查找 {instance_path}/minecraft
        let minecraftPath = instancePath.appendingPathComponent("minecraft")
        if fileManager.fileExists(atPath: minecraftPath.path) {
            return minecraftPath
        }

        // 其次查找 {instance_path}/.minecraft
        let dotMinecraftPath = instancePath.appendingPathComponent(".minecraft")
        if fileManager.fileExists(atPath: dotMinecraftPath.path) {
            return dotMinecraftPath
        }

        return nil
    }
}

// MARK: - MMCPack Models

private struct MMCPack: Codable {
    let components: [MMCPackComponent]
}

private struct MMCPackComponent: Codable {
    let uid: String
    let version: String
}

// MARK: - Import Error

enum ImportError: LocalizedError {
    case gameDirectoryNotFound(instancePath: String)
    case invalidConfiguration(message: String)
    case fileNotFound(path: String)

    var errorDescription: String? {
        switch self {
        case .gameDirectoryNotFound(let path):
            return String(
                format: "launcher.import.error.game_directory_not_found".localized(),
                path
            )
        case .invalidConfiguration(let message):
            return String(
                format: "launcher.import.error.invalid_configuration".localized(),
                message
            )
        case .fileNotFound(let path):
            return String(
                format: "launcher.import.error.file_not_found".localized(),
                path
            )
        }
    }
}
