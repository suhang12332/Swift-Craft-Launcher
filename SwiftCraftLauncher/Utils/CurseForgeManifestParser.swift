import Foundation
import ZIPFoundation

/// CurseForge 整合包 manifest.json 解析器
enum CurseForgeManifestParser {

    // MARK: - Public Methods

    /// 解析 CurseForge 整合包的 manifest.json 文件
    /// - Parameter extractedPath: 解压后的整合包路径
    /// - Returns: 解析后的 Modrinth 索引信息
    static func parseManifest(extractedPath: URL) async -> ModrinthIndexInfo? {
        do {
            // 查找 manifest.json 文件
            let manifestPath = extractedPath.appendingPathComponent("manifest.json")

            Logger.shared.info("尝试解析 CurseForge manifest.json: \(manifestPath.path)")

            guard FileManager.default.fileExists(atPath: manifestPath.path) else {
                // 列出解压目录中的文件，帮助调试
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

            // 获取文件大小
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: manifestPath.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            Logger.shared.info("manifest.json 文件大小: \(fileSize) 字节")

            guard fileSize > 0 else {
                Logger.shared.error("manifest.json 文件为空")
                return nil
            }

            // 读取并解析文件
            let manifestData = try Data(contentsOf: manifestPath)
            Logger.shared.info("成功读取 manifest.json 数据，大小: \(manifestData.count) 字节")

            // 尝试解析 JSON
            let manifest = try JSONDecoder().decode(CurseForgeManifest.self, from: manifestData)

            // 提取加载器信息
            let loaderInfo = determineLoaderInfo(from: manifest.minecraft.modLoaders)

            // 转换为 Modrinth 格式
            let modrinthInfo = await convertToModrinthFormat(
                manifest: manifest,
                loaderInfo: loaderInfo
            )

            Logger.shared.info("解析 CurseForge manifest.json 成功: \(manifest.name) v\(manifest.version)")
            Logger.shared.info("游戏版本: \(manifest.minecraft.version), 加载器: \(loaderInfo.type) \(loaderInfo.version)")
            Logger.shared.info("文件数量: \(manifest.files.count)")

            return modrinthInfo
        } catch {
            Logger.shared.error("解析 CurseForge manifest.json 详细错误: \(error)")

            // 如果是 JSON 解析错误，尝试显示部分内容
            if let jsonError = error as? DecodingError {
                Logger.shared.error("JSON 解析错误: \(jsonError)")
            }

            return nil
        }
    }

    // MARK: - Helper Methods

    /// 从模组加载器列表中确定加载器类型和版本
    /// - Parameter modLoaders: 模组加载器列表
    /// - Returns: 加载器类型和版本
    private static func determineLoaderInfo(from modLoaders: [CurseForgeModLoader]) -> (type: String, version: String) {
        // 查找主要的模组加载器
        guard let primaryLoader = modLoaders.first(where: { $0.primary }) ?? modLoaders.first else {
            return ("vanilla", "unknown")
        }

        let loaderId = primaryLoader.id.lowercased()

        // 解析加载器 ID，格式通常是 "forge-40.2.0" 或 "fabric-0.14.21"
        let components = loaderId.split(separator: "-")

        if components.count >= 2 {
            let loaderType = String(components[0])
            let loaderVersion = components.dropFirst().joined(separator: "-")

            // 标准化加载器类型名称
            let normalizedType = normalizeLoaderType(loaderType)

            return (normalizedType, loaderVersion)
        } else {
            // 如果格式不标准，尝试从 ID 中提取类型
            if loaderId.contains("forge") {
                return ("forge", "unknown")
            } else if loaderId.contains("fabric") {
                return ("fabric", "unknown")
            } else if loaderId.contains("quilt") {
                return ("quilt", "unknown")
            } else if loaderId.contains("neoforge") {
                return ("neoforge", "unknown")
            } else {
                return ("vanilla", "unknown")
            }
        }
    }

    /// 标准化加载器类型名称
    /// - Parameter loaderType: 原始加载器类型
    /// - Returns: 标准化后的加载器类型
    private static func normalizeLoaderType(_ loaderType: String) -> String {
        switch loaderType.lowercased() {
        case "forge":
            return "forge"
        case "fabric":
            return "fabric"
        case "quilt":
            return "quilt"
        case "neoforge":
            return "neoforge"
        default:
            return loaderType.lowercased()
        }
    }

    /// 将 CurseForge manifest 转换为 Modrinth 格式
    /// - Parameters:
    ///   - manifest: CurseForge manifest
    ///   - loaderInfo: 加载器信息
    /// - Returns: Modrinth 索引信息
    private static func convertToModrinthFormat(
        manifest: CurseForgeManifest,
        loaderInfo: (type: String, version: String)
    ) async -> ModrinthIndexInfo {
        Logger.shared.info("转换 CurseForge 格式到 Modrinth 格式，模组数量: \(manifest.files.count)")

        // 优化：不在这里获取文件详情，而是创建延迟解析的文件对象
        // 将真实的文件详情获取延迟到下载阶段，提高导入速度
        var modrinthFiles: [ModrinthIndexFile] = []

        for file in manifest.files {
            // 创建一个占位符文件对象，包含基本信息
            // 真实的文件名、路径和下载URL将在下载时获取
            let placeholderPath = "mods/curseforge_\(file.projectID)_\(file.fileID).jar" // 临时路径

            modrinthFiles.append(ModrinthIndexFile(
                path: placeholderPath,
                hashes: [:], // CurseForge 不提供哈希
                downloads: [], // 下载URL将在下载时获取
                fileSize: 0, // 文件大小将在下载时获取
                env: nil, // 默认环境
                source: .curseforge, // 标记来源为 CurseForge
                // 保存原始的 CurseForge 文件信息用于后续处理
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
            modPackVersion: manifest.version,
            summary: "",
            files: modrinthFiles, // CurseForge 文件转换为 Modrinth 文件（占位符）
            dependencies: [], // CurseForge 格式没有额外的依赖项
            source: .curseforge
        )
    }
}
