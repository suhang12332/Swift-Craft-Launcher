//
//  HMCLSJMCLInstanceParser.swift
//  SwiftCraftLauncher
//
//

import Foundation

/// HMCL 和 SJMCL 使用不同的 JSON 格式
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
            // HMCL: 检查实例文件夹是否包含 文件夹名.json
            let fileManager = FileManager.default

            // 用户选择的是实例文件夹，检查是否包含 文件夹名.json
            let folderName = instancePath.lastPathComponent
            let folderNameJsonPath = instancePath.appendingPathComponent("\(folderName).json")

            // 检查是否存在 文件夹名.json 文件
            if fileManager.fileExists(atPath: folderNameJsonPath.path) {
                // 尝试解析 JSON 文件，验证是否为有效的版本配置文件
                do {
                    let data = try Data(contentsOf: folderNameJsonPath)
                    // 尝试解析为 JSON，检查是否包含必要的字段（如 id）
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       json["id"] != nil {
                        return true
                    }
                } catch {
                    return false
                }
            }

            return false
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

        // 提取信息
        let gameName = sjmclInstance.name.isEmpty ? instancePath.lastPathComponent : sjmclInstance.name
        let gameVersion = sjmclInstance.version
        var modLoader = GameLoader.vanilla.displayName
        var modLoaderVersion = ""

        // 提取 Mod Loader 信息
        if let modLoaderInfo = sjmclInstance.modLoader {
            let loaderType = modLoaderInfo.loaderType.lowercased()
            // 标准化 loader 类型名称
            switch loaderType {
            case GameLoader.fabric.displayName, GameLoader.forge.displayName, GameLoader.neoforge.displayName, GameLoader.quilt.rawValue:
                modLoader = loaderType
            default:
                modLoader = GameLoader.vanilla.displayName
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
            sourceGameDirectory: instancePath,
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

        // 从 文件夹名.json 文件读取信息
        let folderName = instancePath.lastPathComponent
        let folderNameJsonPath = instancePath.appendingPathComponent("\(folderName).json")

        guard fileManager.fileExists(atPath: folderNameJsonPath.path),
              let versionInfo = try? parseHMCLVersionJson(at: folderNameJsonPath) else {
            return nil
        }

        // 从版本 JSON 文件获取信息
        let gameName = versionInfo.id ?? instancePath.lastPathComponent
        let gameVersion = versionInfo.mcVersion ?? ""
        let modLoader = versionInfo.modLoader ?? GameLoader.vanilla.displayName
        let modLoaderVersion = versionInfo.modLoaderVersion ?? ""
        guard let sourceGameDirectory = resolveHMCLSourceGameDirectory(
            instancePath: instancePath,
            basePath: basePath
        ) else {
            return nil
        }

        return ImportInstanceInfo(
            gameName: gameName,
            gameVersion: gameVersion,
            modLoader: modLoader,
            modLoaderVersion: modLoaderVersion,
            gameIconPath: nil,
            iconDownloadUrl: nil,
            sourceGameDirectory: sourceGameDirectory,
            launcherType: launcherType
        )
    }

    /// 解析 HMCL 版本 JSON 文件（文件夹名.json）
    private func parseHMCLVersionJson(at path: URL) throws -> HMCLVersionInfo? {
        guard let data = try? Data(contentsOf: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let id = json["id"] as? String
        let instanceDirectory = path.deletingLastPathComponent()

        var modLoader = GameLoader.vanilla.displayName
        var modLoaderVersion = ""
        var mcVersion = ""

        if let arguments = json["arguments"] as? [String: Any],
           let gameArgs = arguments["game"] as? [Any] {
            // 遍历参数数组，查找 Mod Loader 相关信息
            for (index, arg) in gameArgs.enumerated() {
                if let argString = arg as? String {
                    // 检查 Mod Loader 类型
                    if argString == "--launchTarget" {
                        // 下一个参数是启动目标
                        if index + 1 < gameArgs.count,
                           let launchTarget = gameArgs[index + 1] as? String {
                            switch launchTarget.lowercased() {
                            case "forgeclient", GameLoader.forge.displayName:
                                modLoader = GameLoader.forge.displayName
                            case "fabricclient", GameLoader.fabric.displayName:
                                modLoader = GameLoader.fabric.displayName
                            case "quiltclient", GameLoader.quilt.rawValue:
                                modLoader = GameLoader.quilt.rawValue
                            case "neoforgeclient", GameLoader.neoforge.displayName:
                                modLoader = GameLoader.neoforge.displayName
                            default:
                                break
                            }
                        }
                    }

                    // 检查 Forge 版本
                    if argString == "--fml.forgeVersion" {
                        if index + 1 < gameArgs.count,
                           let version = gameArgs[index + 1] as? String {
                            modLoaderVersion = version
                            if modLoader == GameLoader.vanilla.displayName {
                                modLoader = GameLoader.forge.displayName
                            }
                        }
                    }

                    // 检查 Minecraft 版本
                    if argString == "--fml.mcVersion" {
                        if index + 1 < gameArgs.count,
                           let version = gameArgs[index + 1] as? String {
                            mcVersion = version
                        }
                    }

                    // 检查 NeoForge 版本
                    if argString == "--fml.neoforgeVersion" {
                        if index + 1 < gameArgs.count,
                           let version = gameArgs[index + 1] as? String {
                            modLoaderVersion = version
                            modLoader = GameLoader.neoforge.displayName
                        }
                    }

                    // 检查 Fabric/Quilt 版本（通常在 --version 参数中）
                    if argString == "--version" {
                        if index + 1 < gameArgs.count,
                           let version = gameArgs[index + 1] as? String {
                            // Fabric/Quilt 版本格式通常是 "fabric-loader-0.14.0-1.20.1"
                            if version.contains(GameLoader.fabric.displayName) {
                                modLoader = GameLoader.fabric.displayName
                                let components = version.components(separatedBy: "-")
                                if components.count >= 3 {
                                    modLoaderVersion = components[2] // 提取 loader 版本
                                    if mcVersion.isEmpty && components.count >= 4 {
                                        mcVersion = components[3] // 提取 MC 版本
                                    }
                                }
                            } else if version.contains(GameLoader.quilt.rawValue) {
                                modLoader = GameLoader.quilt.rawValue
                                let components = version.components(separatedBy: "-")
                                if components.count >= 3 {
                                    modLoaderVersion = components[2]
                                    if mcVersion.isEmpty && components.count >= 4 {
                                        mcVersion = components[3]
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        if let patchMetadata = parseHMCLPatchMetadata(from: json) {
            if mcVersion.isEmpty,
               let patchGameVersion = patchMetadata.mcVersion {
                mcVersion = patchGameVersion
            }
            if modLoader == GameLoader.vanilla.displayName,
               let loader = patchMetadata.modLoader {
                modLoader = loader
            }
            if modLoaderVersion.isEmpty,
               let version = patchMetadata.modLoaderVersion {
                modLoaderVersion = version
            }
        }

        if let config = try? parseHMCLConfigJson(
            at: instanceDirectory.appendingPathComponent("hmclversion.cfg")
        ) {
            if mcVersion.isEmpty,
               let gameVersion = config.gameVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
               !gameVersion.isEmpty {
                mcVersion = gameVersion
            }
            if modLoader == GameLoader.vanilla.displayName,
               let loader = normalizedHMCLLoaderName(config.modLoader) {
                modLoader = loader
            }
            if modLoaderVersion.isEmpty,
               let version = config.modLoaderVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
               !version.isEmpty {
                modLoaderVersion = version
            }
        }

        if let modrinthMetadata = parseHMCLModrinthIndexMetadata(
            at: instanceDirectory.appendingPathComponent("modrinth.index.json")
        ) {
            if mcVersion.isEmpty,
               let modrinthGameVersion = modrinthMetadata.mcVersion {
                mcVersion = modrinthGameVersion
            }
            if modLoader == GameLoader.vanilla.displayName,
               let loader = modrinthMetadata.modLoader {
                modLoader = loader
            }
            if modLoaderVersion.isEmpty,
               let version = modrinthMetadata.modLoaderVersion {
                modLoaderVersion = version
            }
        }

        if modLoader == GameLoader.vanilla.displayName,
           let mainClass = (json["mainClass"] as? String)?.lowercased() {
            if mainClass.contains("fabricmc.loader") {
                modLoader = GameLoader.fabric.displayName
            } else if mainClass.contains("quiltmc.loader") {
                modLoader = GameLoader.quilt.rawValue
            } else if mainClass.contains("neoforge") {
                modLoader = GameLoader.neoforge.displayName
            } else if mainClass.contains("fmlloader") || mainClass.contains("forge") {
                modLoader = GameLoader.forge.displayName
            }
        }

        return HMCLVersionInfo(
            id: id,
            mcVersion: mcVersion.isEmpty ? nil : mcVersion,
            modLoader: modLoader == GameLoader.vanilla.displayName ? nil : modLoader,
            modLoaderVersion: modLoaderVersion.isEmpty ? nil : modLoaderVersion
        )
    }

    private func parseHMCLPatchMetadata(from json: [String: Any]) -> HMCLVersionInfo? {
        guard let patches = json["patches"] as? [[String: Any]] else {
            return nil
        }

        var mcVersion = ""
        var modLoader: String?
        var modLoaderVersion: String?

        for patch in patches {
            guard let patchID = (patch["id"] as? String)?.lowercased(),
                  let version = (patch["version"] as? String)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
                  !version.isEmpty else {
                continue
            }

            switch patchID {
            case "game", "minecraft":
                if mcVersion.isEmpty {
                    mcVersion = version
                }
            case GameLoader.fabric.displayName:
                modLoader = GameLoader.fabric.displayName
                if modLoaderVersion == nil {
                    modLoaderVersion = version
                }
            case GameLoader.forge.displayName:
                modLoader = GameLoader.forge.displayName
                if modLoaderVersion == nil {
                    modLoaderVersion = version
                }
            case GameLoader.neoforge.displayName:
                modLoader = GameLoader.neoforge.displayName
                if modLoaderVersion == nil {
                    modLoaderVersion = version
                }
            case GameLoader.quilt.rawValue:
                modLoader = GameLoader.quilt.rawValue
                if modLoaderVersion == nil {
                    modLoaderVersion = version
                }
            default:
                continue
            }
        }

        guard !mcVersion.isEmpty || modLoader != nil || modLoaderVersion != nil else {
            return nil
        }

        return HMCLVersionInfo(
            id: nil,
            mcVersion: mcVersion.isEmpty ? nil : mcVersion,
            modLoader: modLoader,
            modLoaderVersion: modLoaderVersion
        )
    }

    private func parseHMCLModrinthIndexMetadata(at path: URL) -> HMCLVersionInfo? {
        guard let data = try? Data(contentsOf: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dependencies = json["dependencies"] as? [String: Any] else {
            return nil
        }

        let mcVersion = (dependencies["minecraft"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var modLoader: String?
        var modLoaderVersion: String?

        let loaderMapping: [(String, String)] = [
            ("fabric-loader", GameLoader.fabric.displayName),
            ("forge", GameLoader.forge.displayName),
            ("neoforge", GameLoader.neoforge.displayName),
            ("quilt-loader", GameLoader.quilt.rawValue),
        ]

        for (key, loaderName) in loaderMapping {
            guard let version = (dependencies[key] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !version.isEmpty else {
                continue
            }
            modLoader = loaderName
            modLoaderVersion = version
            break
        }

        guard !mcVersion.isEmpty || modLoader != nil || modLoaderVersion != nil else {
            return nil
        }

        return HMCLVersionInfo(
            id: nil,
            mcVersion: mcVersion.isEmpty ? nil : mcVersion,
            modLoader: modLoader,
            modLoaderVersion: modLoaderVersion
        )
    }

    private func normalizedHMCLLoaderName(_ rawValue: String?) -> String? {
        guard let rawValue else {
            return nil
        }

        switch rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() {
        case GameLoader.fabric.displayName:
            return GameLoader.fabric.displayName
        case GameLoader.forge.displayName:
            return GameLoader.forge.displayName
        case GameLoader.neoforge.displayName:
            return GameLoader.neoforge.displayName
        case GameLoader.quilt.rawValue:
            return GameLoader.quilt.rawValue
        default:
            return nil
        }
    }

    /// 解析 HMCL config.json 文件
    private func parseHMCLConfigJson(at path: URL) throws -> HMCLConfig? {
        let data = try Data(contentsOf: path)
        return try? JSONDecoder().decode(HMCLConfig.self, from: data)
    }

    private func resolveHMCLSourceGameDirectory(
        instancePath: URL,
        basePath: URL
    ) -> URL? {
        if hasGameContent(at: instancePath) {
            return instancePath
        }

        let configURL = instancePath.appendingPathComponent("hmclversion.cfg")
        guard let config = try? parseHMCLConfigJson(at: configURL) else {
            return nil
        }

        if config.gameDirType == 1 {
            return hasGameContent(at: instancePath) ? instancePath : nil
        }

        guard let customGameDir = config.gameDir?.trimmingCharacters(in: .whitespacesAndNewlines),
              !customGameDir.isEmpty else {
            return nil
        }

        let resolvedURL: URL
        if customGameDir.hasPrefix("/") {
            resolvedURL = URL(fileURLWithPath: customGameDir)
        } else {
            resolvedURL = basePath.appendingPathComponent(customGameDir)
        }

        return hasGameContent(at: resolvedURL) ? resolvedURL : nil
    }

    private func hasGameContent(at url: URL) -> Bool {
        let fileManager = FileManager.default
        let markers = [
            AppConstants.DirectoryNames.mods,
            AppConstants.DirectoryNames.config,
            AppConstants.DirectoryNames.saves,
            AppConstants.DirectoryNames.resourcepacks,
            AppConstants.DirectoryNames.shaderpacks,
            AppConstants.DirectoryNames.option,
        ]

        return markers.contains { marker in
            fileManager.fileExists(atPath: url.appendingPathComponent(marker).path)
        }
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
    // 可添加字段
}

// MARK: - HMCL Models

private struct HMCLConfig: Codable {
    let name: String?
    let gameVersion: String?
    let modLoader: String?
    let modLoaderVersion: String?
    let gameDir: String?
    let gameDirType: Int?
}

private struct HMCLVersionInfo {
    let id: String?
    let mcVersion: String?
    let modLoader: String?
    let modLoaderVersion: String?
}
