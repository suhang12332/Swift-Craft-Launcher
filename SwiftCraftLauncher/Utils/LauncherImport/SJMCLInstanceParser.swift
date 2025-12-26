//
//  HMCLSJMCLInstanceParser.swift
//  SwiftCraftLauncher
//
//

import Foundation

/// HMCL/SJMCLauncher 实例解析器
/// 注意：HMCL 和 SJMCL 使用不同的 JSON 格式
struct SJMCLInstanceParser: LauncherInstanceParser {
    let launcherType: ImportLauncherType

    func isValidInstance(at instancePath: URL) -> Bool {
        let fileManager = FileManager.default

        // 根据启动器类型使用不同的验证逻辑
        if launcherType == .sjmcLauncher {
            // SJMCL: 检查是否存在 sjmclcfg.json 文件
            let sjmclcfgPath = instancePath.appendingPathComponent("sjmclcfg.json")
            if fileManager.fileExists(atPath: sjmclcfgPath.path) {
                // 验证 JSON 文件可以解析
                do {
                    _ = try parseSJMCLInstanceJson(at: sjmclcfgPath)
                    return true
                } catch {
                    return false
                }
            }
            return false
        } else {
            // HMCL: 检查是否存在 .minecraft 文件夹或实例配置文件
            let minecraftPath = instancePath.appendingPathComponent(".minecraft")
            let configJsonPath = instancePath.appendingPathComponent("config.json")

            // 如果实例路径本身就是 .minecraft 目录（HMCL 的情况）
            if instancePath.lastPathComponent == ".minecraft" {
                return fileManager.fileExists(atPath: instancePath.path)
            }

            // 检查是否有 .minecraft 子文件夹或配置文件
            return fileManager.fileExists(atPath: minecraftPath.path) ||
                   fileManager.fileExists(atPath: configJsonPath.path)
        }
    }

    func parseInstance(at instancePath: URL, basePath: URL) throws -> ImportInstanceInfo? {
        // 根据启动器类型使用不同的解析逻辑
        if launcherType == .sjmcLauncher {
            return try parseSJMCLInstance(at: instancePath, basePath: basePath)
        } else {
            return try parseHMCLInstance(at: instancePath, basePath: basePath)
        }
    }

    // MARK: - SJMCL Parsing

    /// 解析 SJMCL 实例
    private func parseSJMCLInstance(at instancePath: URL, basePath: URL) throws -> ImportInstanceInfo? {
        let fileManager = FileManager.default

        // 读取 sjmclcfg.json 文件
        let sjmclcfgPath = instancePath.appendingPathComponent("sjmclcfg.json")
        guard fileManager.fileExists(atPath: sjmclcfgPath.path) else {
            return nil
        }

        let sjmclInstance = try parseSJMCLInstanceJson(at: sjmclcfgPath)

        // 确定游戏目录
        // SJMCL 使用 versionPath 指向的版本文件夹作为游戏目录
        let gameDirectory: URL
        if let versionPath = sjmclInstance.versionPath, !versionPath.isEmpty {
            gameDirectory = URL(fileURLWithPath: versionPath)
        } else {
            // 如果没有 versionPath，使用实例路径本身
            gameDirectory = instancePath
        }

        // 提取信息
        let gameName = sjmclInstance.name.isEmpty ? instancePath.lastPathComponent : sjmclInstance.name
        let gameVersion = sjmclInstance.version
        var modLoader = "vanilla"
        var modLoaderVersion = ""

        // 提取 Mod Loader 信息
        if let modLoaderInfo = sjmclInstance.modLoader {
            let loaderType = modLoaderInfo.loaderType.lowercased()
            // 标准化 loader 类型名称
            switch loaderType {
            case "fabric":
                modLoader = "fabric"
            case "forge":
                modLoader = "forge"
            case "neoforge", "neoforged":
                modLoader = "neoforge"
            case "quilt":
                modLoader = "quilt"
            default:
                modLoader = "vanilla"
            }
            modLoaderVersion = modLoaderInfo.version
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

    /// 解析 SJMCL 实例 JSON 文件
    private func parseSJMCLInstanceJson(at path: URL) throws -> SJMCLInstance {
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(SJMCLInstance.self, from: data)
    }

    // MARK: - HMCL Parsing

    /// 解析 HMCL 实例
    private func parseHMCLInstance(at instancePath: URL, basePath: URL) throws -> ImportInstanceInfo? {
        let fileManager = FileManager.default

        // 确定游戏目录
        let gameDirectory: URL
        if instancePath.lastPathComponent == ".minecraft" {
            // HMCL 的情况：实例路径本身就是 .minecraft
            gameDirectory = instancePath
        } else {
            // 查找 .minecraft 子文件夹
            let minecraftPath = instancePath.appendingPathComponent(".minecraft")
            if fileManager.fileExists(atPath: minecraftPath.path) {
                gameDirectory = minecraftPath
            } else {
                // 如果没有 .minecraft 子文件夹，使用实例路径本身
                gameDirectory = instancePath
            }
        }

        // 尝试从配置文件读取信息
        let configJsonPath = instancePath.appendingPathComponent("config.json")
        var gameName = instancePath.lastPathComponent
        var gameVersion = ""
        var modLoader = "vanilla"
        var modLoaderVersion = ""

        if fileManager.fileExists(atPath: configJsonPath.path) {
            if let config = try? parseHMCLConfigJson(at: configJsonPath) {
                gameName = config.name ?? gameName
                gameVersion = config.gameVersion ?? ""
                modLoader = config.modLoader?.lowercased() ?? "vanilla"
                modLoaderVersion = config.modLoaderVersion ?? ""
            }
        }

        // 如果无法从配置文件获取版本，尝试从版本文件读取
        if gameVersion.isEmpty {
            if let version = try? extractVersionFromGameDirectory(gameDirectory) {
                gameVersion = version
            }
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

    /// 解析 HMCL config.json 文件
    private func parseHMCLConfigJson(at path: URL) throws -> HMCLConfig? {
        let data = try Data(contentsOf: path)
        return try? JSONDecoder().decode(HMCLConfig.self, from: data)
    }

    // MARK: - Common Methods

    /// 从游戏目录提取版本信息
    private func extractVersionFromGameDirectory(_ gameDirectory: URL) throws -> String? {
        // 尝试从版本文件读取
        let versionFile = gameDirectory.appendingPathComponent("version.json")
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: versionFile.path) {
            if let data = try? Data(contentsOf: versionFile),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let version = json["id"] as? String {
                return version
            }
        }

        return nil
    }
}

// MARK: - SJMCL Models
// swiftlint:disable discouraged_optional_boolean

private struct SJMCLInstance: Codable {
    let id: String
    let name: String
    let description: String?
    let iconSrc: String
    let starred: Bool?
    let playTime: Int64?
    let version: String
    let versionPath: String?
    let modLoader: SJMCLModLoader?
    let useSpecGameConfig: Bool?
    let specGameConfig: SJMCLSpecGameConfig?
}

// swiftlint:enable discouraged_optional_boolean

private struct SJMCLModLoader: Codable {
    let status: String
    let loaderType: String
    let version: String
    let branch: String?
}

private struct SJMCLSpecGameConfig: Codable {
    // 如果需要可以添加字段
}

// MARK: - HMCL Models

private struct HMCLConfig: Codable {
    let name: String?
    let gameVersion: String?
    let modLoader: String?
    let modLoaderVersion: String?
}
