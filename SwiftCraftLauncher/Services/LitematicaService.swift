//
//  LitematicaService.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/20.
//

import Foundation

/// Litematica 投影文件服务
/// 负责读取和解析 Litematica 投影文件
@MainActor
class LitematicaService {
    static let shared = LitematicaService()

    private init() {}

    /// 从游戏目录读取 Litematica 投影文件列表
    /// - Parameter gameName: 游戏名称
    /// - Returns: Litematica 投影文件列表
    func loadLitematicaFiles(for gameName: String) async throws -> [LitematicaInfo] {
        let schematicsDir = AppPaths.schematicsDirectory(gameName: gameName)

        guard FileManager.default.fileExists(atPath: schematicsDir.path) else {
            return []
        }

        var litematicaFiles: [LitematicaInfo] = []

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: schematicsDir,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .creationDateKey,
                    .fileSizeKey,
                ],
                options: [.skipsHiddenFiles]
            )

            for filePath in contents {
                guard let isFile = try? filePath.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                      isFile == true else {
                    continue
                }

                // 只处理 .litematic 文件
                let fileExtension = filePath.pathExtension.lowercased()
                guard fileExtension == "litematic" else {
                    continue
                }

                let fileName = filePath.lastPathComponent
                let creationDate = try? filePath.resourceValues(forKeys: [.creationDateKey]).creationDate
                let fileSize = (try? filePath.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

                // 尝试解析 Litematica 文件获取元数据
                let metadata = try? await parseLitematicaMetadata(filePath: filePath)

                let litematicaInfo = LitematicaInfo(
                    name: fileName,
                    path: filePath,
                    createdDate: creationDate,
                    fileSize: Int64(fileSize),
                    author: metadata?.author,
                    description: metadata?.description,
                    version: metadata?.version,
                    regionCount: metadata?.regionCount,
                    totalBlocks: metadata?.totalBlocks
                )

                litematicaFiles.append(litematicaInfo)
            }

            // 按创建时间排序
            litematicaFiles.sort { file1, file2 in
                let date1 = file1.createdDate ?? Date.distantPast
                let date2 = file2.createdDate ?? Date.distantPast
                return date1 > date2
            }

            return litematicaFiles
        } catch {
            Logger.shared.error("读取 Litematica 文件列表失败: \(error.localizedDescription)")
            throw GlobalError.fileSystem(
                chineseMessage: "读取 Litematica 文件列表失败",
                i18nKey: "error.filesystem.litematica_list_read_failed",
                level: .notification
            )
        }
    }

    /// 解析 Litematica 文件的元数据（用于列表显示）
    /// - Parameter filePath: 文件路径
    /// - Returns: 元数据信息
    private func parseLitematicaMetadata(filePath: URL) async throws -> LitematicaMetadata? {
        let data = try Data(contentsOf: filePath)
        let parser = NBTParser(data: data)
        let nbtData = try parser.parse()

        // Litematica 文件结构：
        // TAG_Compound("")
        //   TAG_Compound("Metadata")
        //     TAG_String("Author") - 作者
        //     TAG_String("Description") - 描述
        //     TAG_String("Version") - 版本
        //   TAG_Compound("Regions") - 区域列表
        //     TAG_Compound(regionName)
        //       TAG_Int("BlockCount") - 方块数量

        guard let metadata = nbtData["Metadata"] as? [String: Any] else {
            return nil
        }

        let author = metadata["Author"] as? String
        let description = metadata["Description"] as? String
        let version = metadata["Version"] as? String

        // 只从 Metadata 读取区域数量和总方块数，避免遍历 Regions 触发方块数据解析
        var regionCount: Int?
        var totalBlocks: Int?

        if let rc = metadata["RegionCount"] {
            if let rcInt = rc as? Int32 {
                regionCount = Int(rcInt)
            } else if let rcInt = rc as? Int {
                regionCount = rcInt
            }
        }

        if let tb = metadata["TotalBlocks"] {
            if let tbInt = tb as? Int32 {
                totalBlocks = Int(tbInt)
            } else if let tbInt = tb as? Int {
                totalBlocks = tbInt
            }
        }

        return LitematicaMetadata(
            author: author,
            description: description,
            version: version,
            regionCount: regionCount,
            totalBlocks: totalBlocks
        )
    }

    /// 读取完整的 Litematica 投影元数据
    /// - Parameter filePath: 文件路径
    /// - Returns: 完整的元数据信息
    func loadFullMetadata(filePath: URL) async throws -> LitematicMetadata? {
        do {
            let data = try Data(contentsOf: filePath)
            Logger.shared.debug("开始解析Litematica文件: \(filePath.lastPathComponent), 大小: \(data.count) 字节")

            let parser = NBTParser(data: data)
            let nbtData = try parser.parse()

            Logger.shared.debug("NBT解析成功，根键: \(Array(nbtData.keys))")

            // Litematica 文件结构：
            // TAG_Compound("")
            //   TAG_Compound("Metadata")
            //     TAG_String("Name") - 名称
            //     TAG_String("Author") - 作者
            //     TAG_String("Description") - 描述
            //     TAG_Long("TimeCreated") - 创建时间
            //     TAG_Long("TimeModified") - 修改时间
            //     TAG_Int("TotalVolume") - 总体积
            //     TAG_Int("TotalBlocks") - 总方块数
            //     TAG_Int("RegionCount") - 区域数量
            //     TAG_Compound("EnclosingSize") - 包围盒尺寸
            //       TAG_Int("x")
            //       TAG_Int("y")
            //       TAG_Int("z")
            //   TAG_Compound("Regions") - 区域列表

            guard let metadata = nbtData["Metadata"] as? [String: Any] else {
                Logger.shared.warning("Litematica文件缺少Metadata标签: \(filePath.lastPathComponent)")
                Logger.shared.debug("可用的NBT键: \(Array(nbtData.keys))")
                return nil
            }

            Logger.shared.debug("Metadata键: \(Array(metadata.keys))")

            // 读取基本信息
            let name = (metadata["Name"] as? String) ?? filePath.deletingPathExtension().lastPathComponent
            let author = (metadata["Author"] as? String) ?? ""
            let description = (metadata["Description"] as? String) ?? ""

            // 读取时间戳 - 尝试不同的类型转换
            var timeCreated: Int64 = 0
            var timeModified: Int64 = 0

            if let tc = metadata["TimeCreated"] {
                if let tcLong = tc as? Int64 {
                    timeCreated = tcLong
                } else if let tcInt = tc as? Int32 {
                    timeCreated = Int64(tcInt)
                } else if let tcInt = tc as? Int {
                    timeCreated = Int64(tcInt)
                }
            }

            if let tm = metadata["TimeModified"] {
                if let tmLong = tm as? Int64 {
                    timeModified = tmLong
                } else if let tmInt = tm as? Int32 {
                    timeModified = Int64(tmInt)
                } else if let tmInt = tm as? Int {
                    timeModified = Int64(tmInt)
                }
            }

            // 读取尺寸信息（仅从 Metadata 读取，避免遍历 Regions 触发方块数据解析）
            var enclosingSize = Size(x: 0, y: 0, z: 0)
            if let sizeData = metadata["EnclosingSize"] as? [String: Any] {
                let x = (sizeData["x"] as? Int32) ?? 0
                let y = (sizeData["y"] as? Int32) ?? 0
                let z = (sizeData["z"] as? Int32) ?? 0
                enclosingSize = Size(x: x, y: y, z: z)
                Logger.shared.debug("读取到包围盒尺寸: \(x) × \(y) × \(z)")
            } else {
                Logger.shared.debug("未找到EnclosingSize，使用默认值 (0, 0, 0)")
            }

            // 读取总体积和总方块数
            var totalVolume: Int32 = 0
            var totalBlocks: Int32 = 0

            if let tv = metadata["TotalVolume"] {
                if let tvInt = tv as? Int32 {
                    totalVolume = tvInt
                } else if let tvInt = tv as? Int {
                    totalVolume = Int32(tvInt)
                }
            }

            if let tb = metadata["TotalBlocks"] {
                if let tbInt = tb as? Int32 {
                    totalBlocks = tbInt
                } else if let tbInt = tb as? Int {
                    totalBlocks = Int32(tbInt)
                }
            }

            // 计算区域数量（仅从 Metadata 读取，避免遍历 Regions 触发方块数据解析）
            var regionCount: Int32 = 0
            if let rc = metadata["RegionCount"] {
                if let rcInt = rc as? Int32 {
                    regionCount = rcInt
                } else if let rcInt = rc as? Int {
                    regionCount = Int32(rcInt)
                }
            }

            return LitematicMetadata(
                name: name,
                author: author,
                description: description,
                timeCreated: timeCreated,
                timeModified: timeModified,
                totalVolume: totalVolume,
                totalBlocks: totalBlocks,
                enclosingSize: enclosingSize,
                regionCount: regionCount
            )
        } catch {
            Logger.shared.error("解析Litematica文件失败: \(filePath.lastPathComponent), 错误: \(error)")
            throw error
        }
    }
}
