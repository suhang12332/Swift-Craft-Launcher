//
//  XMCLInstanceParser.swift
//  SwiftCraftLauncher
//
//

import Foundation

/// XMCL 实例解析器
struct XMCLInstanceParser: LauncherInstanceParser {
    let launcherType: ImportLauncherType = .xmcl

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
        let instance = try parseInstanceJson(at: instanceJsonPath)

        // 提取游戏版本
        let gameVersion = instance.runtime.minecraft

        // 提取 Mod 加载器信息
        let (modLoader, modLoaderVersion) = extractModLoader(from: instance)

        // 提取游戏名称
        let gameName = instance.name.isEmpty ? "XMCL-\(instancePath.lastPathComponent)" : instance.name

        return ImportInstanceInfo(
            gameName: gameName,
            gameVersion: gameVersion,
            modLoader: modLoader,
            modLoaderVersion: modLoaderVersion,
            gameIconPath: nil,
            iconDownloadUrl: nil,
            sourceGameDirectory: instancePath,
            instanceFolder: instancePath,
            launcherType: launcherType
        )
    }

    // MARK: - Private Methods

    /// 解析 instance.json 文件
    private func parseInstanceJson(at path: URL) throws -> XMCLInstance {
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(XMCLInstance.self, from: data)
    }

    /// 提取 Mod Loader 信息
    private func extractModLoader(from instance: XMCLInstance) -> (loader: String, version: String) {
        let runtime = instance.runtime

        // 按优先级检查：Forge -> NeoForged -> Fabric -> Quilt -> Vanilla
        if !runtime.forge.isEmpty {
            return ("forge", runtime.forge)
        } else if !runtime.neoForged.isEmpty {
            return ("neoforge", runtime.neoForged)
        } else if !runtime.fabricLoader.isEmpty {
            return ("fabric", runtime.fabricLoader)
        } else if !runtime.quiltLoader.isEmpty {
            return ("quilt", runtime.quiltLoader)
        } else {
            return ("vanilla", "")
        }
    }
}

// MARK: - XMCL Models

private struct XMCLInstance: Codable {
    let name: String
    let url: String
    let icon: String
    let runtime: XMCLRuntime
    let java: String
    let version: String
    let server: XMCLServer?
    let author: String
    let description: String
    let lastAccessDate: Int64
    let creationDate: Int64
    let modpackVersion: String
    let fileApi: String
    let tags: [String]
    let lastPlayedDate: Int64
    let playtime: Int64
}

private struct XMCLRuntime: Codable {
    let minecraft: String
    let forge: String
    let liteloader: String
    let fabricLoader: String
    let yarn: String
    let optifine: String
    let quiltLoader: String
    let neoForged: String
    let labyMod: String
}

private struct XMCLServer: Codable {
    // 服务器信息，如果需要可以添加字段
}
