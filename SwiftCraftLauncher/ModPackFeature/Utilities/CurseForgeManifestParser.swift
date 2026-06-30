//
//  CurseForgeManifestParser.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import ZIPFoundation

/// Parses a CurseForge modpack's manifest.json file.
enum CurseForgeManifestParser {

    /// Parses the manifest.json file within an extracted CurseForge modpack.
    /// - Parameter extractedPath: The path to the extracted modpack directory.
    /// - Returns: The parsed Modrinth index information, or `nil` if parsing fails.
    static func parseManifest(extractedPath: URL) async -> ModrinthIndexInfo? {
        do {
            let manifestPath = extractedPath.appendingPathComponent("manifest.json")

            Logger.shared.info("尝试解析 CurseForge manifest.json: \(manifestPath.path)")

            guard FileManager.default.fileExists(atPath: manifestPath.path) else {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(
                        at: extractedPath,
                        includingPropertiesForKeys: nil
                    )
                    Logger.shared.info("解压目录内容: \(contents.map { $0.lastPathComponent })")
                } catch {
                    Logger.shared.error("无法列出解压目录内容: \(error.localizedDescription)")
                }

                Logger.shared.warning("CurseForge 整合包中未找到 manifest.json 文件")
                return nil
            }

            let fileAttributes = try FileManager.default.attributesOfItem(atPath: manifestPath.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            Logger.shared.info("manifest.json 文件大小: \(fileSize) 字节")

            guard fileSize > 0 else {
                Logger.shared.error("manifest.json 文件为空")
                return nil
            }

            let manifestData = try Data(contentsOf: manifestPath)
            Logger.shared.info("成功读取 manifest.json 数据，大小: \(manifestData.count) 字节")

            let manifest = try JSONDecoder().decode(CurseForgeManifest.self, from: manifestData)

            let loaderInfo = determineLoaderInfo(from: manifest.minecraft.modLoaders)

            let modPackVersion = manifest.version ?? generateAutoVersion(
                modPackName: manifest.name,
                gameVersion: manifest.minecraft.version,
                loaderInfo: loaderInfo
            )

            let modrinthInfo = await convertToModrinthFormat(
                manifest: manifest,
                loaderInfo: loaderInfo,
                generatedVersion: modPackVersion
            )

            Logger.shared.info("解析 CurseForge manifest.json 成功: \(manifest.name) v\(modPackVersion)")
            if manifest.version == nil {
                Logger.shared.info("⚠️ 整合包缺少version字段，已自动生成版本: \(modPackVersion)")
            }
            Logger.shared.info("游戏版本: \(manifest.minecraft.version), 加载器: \(loaderInfo.type) \(loaderInfo.version)")
            Logger.shared.info("文件数量: \(manifest.files.count)")

            return modrinthInfo
        } catch {
            Logger.shared.error("解析 CurseForge manifest.json 详细错误: \(error)")

            if let jsonError = error as? DecodingError {
                Logger.shared.error("JSON 解析错误: \(jsonError)")
            }

            return nil
        }
    }

    /// Determines the loader type and version from a list of mod loaders.
    /// - Parameter modLoaders: The list of mod loaders from the manifest.
    /// - Returns: A tuple containing the loader type and version.
    private static func determineLoaderInfo(from modLoaders: [CurseForgeModLoader]) -> (type: String, version: String) {
        guard let primaryLoader = modLoaders.first(where: { $0.primary }) ?? modLoaders.first else {
            return (GameLoader.vanilla.displayName, "unknown")
        }

        let loaderId = primaryLoader.id.lowercased()

        let components = loaderId.split(separator: "-")

        if components.count >= 2 {
            let loaderType = String(components[0])
            let loaderVersion = components.dropFirst().joined(separator: "-")

            let normalizedType = normalizeLoaderType(loaderType)

            return (normalizedType, loaderVersion)
        } else {
            if loaderId.contains(GameLoader.forge.displayName) {
                return (GameLoader.forge.displayName, "unknown")
            } else if loaderId.contains(GameLoader.fabric.displayName) {
                return (GameLoader.fabric.displayName, "unknown")
            } else if loaderId.contains(GameLoader.quilt.rawValue) {
                return (GameLoader.quilt.rawValue, "unknown")
            } else if loaderId.contains(GameLoader.neoforge.displayName) {
                return (GameLoader.neoforge.displayName, "unknown")
            } else {
                return (GameLoader.vanilla.displayName, "unknown")
            }
        }
    }

    /// Normalizes a loader type string to its canonical display name.
    /// - Parameter loaderType: The raw loader type string.
    /// - Returns: The normalized loader type.
    private static func normalizeLoaderType(_ loaderType: String) -> String {
        switch loaderType.lowercased() {
        case GameLoader.forge.displayName:
            return GameLoader.forge.displayName
        case GameLoader.fabric.displayName:
            return GameLoader.fabric.displayName
        case GameLoader.quilt.rawValue:
            return GameLoader.quilt.rawValue
        case GameLoader.neoforge.displayName:
            return GameLoader.neoforge.displayName
        default:
            return loaderType.lowercased()
        }
    }

    /// Generates an automatic version string for a modpack.
    /// - Parameters:
    ///   - modPackName: The name of the modpack.
    ///   - gameVersion: The Minecraft game version.
    ///   - loaderInfo: The mod loader information.
    /// - Returns: A generated version string in the format `gameVersion-loaderType-date`.
    private static func generateAutoVersion(
        modPackName: String,
        gameVersion: String,
        loaderInfo: (type: String, version: String)
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: Date())

        let autoVersion = "\(gameVersion)-\(loaderInfo.type)-\(dateString)"

        Logger.shared.info("自动生成整合包版本: \(autoVersion)")
        return autoVersion
    }

    /// Converts a CurseForge manifest to Modrinth index format.
    /// - Parameters:
    ///   - manifest: The CurseForge manifest to convert.
    ///   - loaderInfo: The mod loader information.
    ///   - generatedVersion: The version string (used when the manifest lacks a version field).
    /// - Returns: A Modrinth index info with placeholder file entries.
    private static func convertToModrinthFormat(
        manifest: CurseForgeManifest,
        loaderInfo: (type: String, version: String),
        generatedVersion: String
    ) async -> ModrinthIndexInfo {
        Logger.shared.info("转换 CurseForge 格式到 Modrinth 格式，模组数量: \(manifest.files.count)")

        var modrinthFiles: [ModrinthIndexFile] = []

        for file in manifest.files {
            let placeholderPath = "mods/curseforge_\(file.projectID)_\(file.fileID).jar"

            modrinthFiles.append(ModrinthIndexFile(
                path: placeholderPath,
                hashes: ModrinthIndexFileHashes(from: [:]),
                downloads: [],
                fileSize: 0,
                env: nil,
                source: .curseforge,
                curseForgeProjectId: file.projectID,
                curseForgeFileId: file.fileID
            ))
        }

        Logger.shared.info("快速转换完成，将在下载阶段获取详细信息")

        return ModrinthIndexInfo(
            gameVersion: manifest.minecraft.version,
            loaderType: loaderInfo.type,
            loaderVersion: loaderInfo.version,
            modPackName: manifest.name,
            modPackVersion: generatedVersion,
            summary: "",
            files: modrinthFiles,
            dependencies: [],
            source: .curseforge
        )
    }
}
