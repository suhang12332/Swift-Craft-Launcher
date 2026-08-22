//
//  MMCIndexAdapter.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Parses MultiMC / PrismLauncher mod pack archives into a normalized index representation.
///
/// MMC packs are identified by the presence of `mmc-pack.json` (component profile)
/// and optionally `instance.cfg` (instance metadata). The actual game files live in
/// the `minecraft/` subdirectory, which is treated as an overrides folder during
/// installation.
struct MMCIndexAdapter: ModPackIndexAdapter {
    let id: String = "mmc"

    // MARK: - Internal Types

    /// Parsed result from mmc-pack.json.
    private struct MMCPackInfo {
        let minecraftVersion: String
        let loaderInfo: (type: String, version: String)
        let name: String?
        let version: String?
    }

    // MARK: - ModPackIndexAdapter

    func canParse(extractedPath: URL) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            let packJsonPath = extractedPath.appendingPathComponent("mmc-pack.json").path
            return FileManager.default.fileExists(atPath: packJsonPath)
        }.value
    }

    func parseToModrinthIndexInfo(extractedPath: URL) async -> ModrinthIndexInfo? {
        guard let packJson = await parsePackJson(extractedPath: extractedPath) else {
            return nil
        }

        let gameVersion = packJson.minecraftVersion
        let loaderInfo = packJson.loaderInfo
        let instanceName = await parseInstanceCfgName(extractedPath: extractedPath)
        let modPackName = instanceName ?? packJson.name ?? "MMC Modpack"

        AppLog.modPack.info(
            "MMC pack parsed: \(modPackName) — Minecraft \(gameVersion), loader: \(loaderInfo.type) \(loaderInfo.version)"
        )

        return ModrinthIndexInfo(
            gameVersion: gameVersion,
            loaderType: loaderInfo.type,
            loaderVersion: loaderInfo.version,
            modPackName: modPackName,
            modPackVersion: packJson.version ?? "mmc",
            summary: nil,
            files: [],
            dependencies: [],
            source: .mmc,
        )
    }

    // MARK: - mmc-pack.json parsing

    private func parsePackJson(extractedPath: URL) async -> MMCPackInfo? {
        let packJsonPath = extractedPath.appendingPathComponent("mmc-pack.json")

        return await Task.detached(priority: .userInitiated) {
            guard FileManager.default.fileExists(atPath: packJsonPath.path) else {
                AppLog.modPack.error("mmc-pack.json not found at \(packJsonPath.path)")
                return nil
            }

            guard let data = try? Data(contentsOf: packJsonPath), !data.isEmpty else {
                AppLog.modPack.error("mmc-pack.json is empty or unreadable")
                return nil
            }

            let decoder = JSONDecoder()
            guard let pack = try? decoder.decode(MMCPackJson.self, from: data) else {
                AppLog.modPack.error("Failed to decode mmc-pack.json: invalid JSON structure")
                return nil
            }

            // Extract Minecraft version and loader info from components.
            var minecraftVersion: String?
            var loaderType: String?
            var loaderVersion: String?

            for component in pack.components {
                let uid = component.uid.lowercased()
                switch uid {
                case "net.minecraft":
                    minecraftVersion = component.version
                case "net.fabricmc.fabric-loader":
                    loaderType = GameLoader.fabric.displayName
                    loaderVersion = component.version
                case "org.quiltmc.quilt-loader":
                    loaderType = GameLoader.quilt.rawValue
                    loaderVersion = component.version
                case "net.minecraftforge":
                    loaderType = GameLoader.forge.displayName
                    loaderVersion = component.version
                case "net.neoforge":
                    loaderType = GameLoader.neoforge.displayName
                    loaderVersion = component.version
                default:
                    break
                }
            }

            guard let mcVersion = minecraftVersion else {
                AppLog.modPack.error("mmc-pack.json does not contain a net.minecraft component")
                return nil
            }

            let resolvedLoaderType = loaderType ?? GameLoader.vanilla.displayName
            let resolvedLoaderVersion = loaderVersion ?? "unknown"

            return MMCPackInfo(
                minecraftVersion: mcVersion,
                loaderInfo: (resolvedLoaderType, resolvedLoaderVersion),
                name: pack.name,
                version: pack.versionId
            )
        }.value
    }

    // MARK: - instance.cfg parsing

    private func parseInstanceCfgName(extractedPath: URL) async -> String? {
        await Task.detached(priority: .userInitiated) {
            let cfgPath = extractedPath.appendingPathComponent("instance.cfg")
            guard FileManager.default.fileExists(atPath: cfgPath.path),
                  let data = try? Data(contentsOf: cfgPath),
                  let content = String(data: data, encoding: .utf8)
            else {
                return nil
            }

            return Self.parseIniValue(content: content, key: "name")
        }.value
    }

    /// Parses a simple INI file and returns the value for the given key from any section.
    private static func parseIniValue(content: String, key: String) -> String? {
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip section headers and comments.
            if trimmed.hasPrefix("[") || trimmed.hasPrefix("#") || trimmed.hasPrefix(";") {
                continue
            }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let k = parts[0].trimmingCharacters(in: .whitespaces)
                let v = parts[1].trimmingCharacters(in: .whitespaces)
                if k == key {
                    return v.isEmpty ? nil : v
                }
            }
        }
        return nil
    }
}

// MARK: - mmc-pack.json models

/// Top-level structure of `mmc-pack.json`.
private struct MMCPackJson: Codable {
    let formatVersion: Int?
    let components: [MMCComponent]
    let name: String?
    let versionId: String?

    enum CodingKeys: String, CodingKey {
        case formatVersion
        case components
        case name
        case versionId
    }
}

/// A single component entry in `mmc-pack.json`.
private struct MMCComponent: Codable {
    let uid: String
    let version: String?

    enum CodingKeys: String, CodingKey {
        case uid
        case version
    }
}
