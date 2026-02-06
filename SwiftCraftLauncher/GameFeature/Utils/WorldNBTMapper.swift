import Foundation

/// 与 Minecraft 世界存档（level.dat / world_gen_settings.dat 等）相关的通用 NBT 解析工具
enum WorldNBTMapper {
    // MARK: - 基本数值/布尔读取

    /// 尝试将任意 NBT 数值类型统一转换为 Int64，兼容 Int/Int8/Int16/Int32/UInt 等
    static func readInt64(_ any: Any?) -> Int64? {
        if let v = any as? Int64 { return v }
        if let v = any as? Int { return Int64(v) }
        if let v = any as? Int32 { return Int64(v) }
        if let v = any as? Int16 { return Int64(v) }
        if let v = any as? Int8 { return Int64(v) }
        if let v = any as? UInt64 { return Int64(v) }
        if let v = any as? UInt32 { return Int64(v) }
        if let v = any as? UInt16 { return Int64(v) }
        if let v = any as? UInt8 { return Int64(v) }
        return nil
    }

    /// 将 NBT 中的数值或布尔统一转换为 Bool（非 0 即 true）
    static func readBoolFlag(_ any: Any?) -> Bool? {
        if any == nil { return nil }
        if let b = any as? Bool { return b }
        if let v = readInt64(any) { return v != 0 }
        return nil
    }

    // MARK: - 游戏模式 / 难度

    static func mapGameMode(_ value: Int) -> String {
        switch value {
        case 0: return "saveinfo.world.game_mode.survival".localized()
        case 1: return "saveinfo.world.game_mode.creative".localized()
        case 2: return "saveinfo.world.game_mode.adventure".localized()
        case 3: return "saveinfo.world.game_mode.spectator".localized()
        default: return "saveinfo.world.game_mode.unknown".localized()
        }
    }

    static func mapDifficulty(_ value: Int) -> String {
        switch value {
        case 0: return "saveinfo.world.difficulty.peaceful".localized()
        case 1: return "saveinfo.world.difficulty.easy".localized()
        case 2: return "saveinfo.world.difficulty.normal".localized()
        case 3: return "saveinfo.world.difficulty.hard".localized()
        default: return "saveinfo.world.difficulty.unknown".localized()
        }
    }

    /// 将新版 difficulty_settings.difficulty（字符串）映射为本地化文本
    static func mapDifficultyString(_ value: String) -> String {
        switch value.lowercased() {
        case "peaceful": return "saveinfo.world.difficulty.peaceful".localized()
        case "easy": return "saveinfo.world.difficulty.easy".localized()
        case "normal": return "saveinfo.world.difficulty.normal".localized()
        case "hard": return "saveinfo.world.difficulty.hard".localized()
        default: return "saveinfo.world.difficulty.unknown".localized()
        }
    }

    // MARK: - 种子读取

    /// 从 level.dat 的 Data 标签和可选的 world 路径中解析种子
    /// - 优先 RandomSeed
    /// - 其次 WorldGenSettings/worldGenSettings.seed
    /// - 最后（如有 worldPath）尝试 data/minecraft/world_gen_settings.dat -> data.seed
    static func readSeed(from dataTag: [String: Any], worldPath: URL?) -> Int64? {
        // 旧版：优先从 RandomSeed 读取
        if let seed = readInt64(dataTag["RandomSeed"]) {
            return seed
        }

        // 其次：level.dat 中 WorldGenSettings / worldGenSettings.seed
        if let worldGenSettings = dataTag["WorldGenSettings"] as? [String: Any],
           let seed = readInt64(worldGenSettings["seed"]) {
            return seed
        }
        if let worldGenSettings = dataTag["worldGenSettings"] as? [String: Any],
           let seed = readInt64(worldGenSettings["seed"]) {
            return seed
        }

        // 新版：world_gen_settings.dat
        guard let worldPath else { return nil }
        return readSeedFromWorldGenSettings(worldPath: worldPath)
    }

    /// 从 26+ 新版存档的 world_gen_settings.dat 读取 seed（路径: data/minecraft/world_gen_settings.dat）
    private static func readSeedFromWorldGenSettings(worldPath: URL) -> Int64? {
        let fm = FileManager.default
        let wgsPath = worldPath
            .appendingPathComponent("data", isDirectory: true)
            .appendingPathComponent("minecraft", isDirectory: true)
            .appendingPathComponent("world_gen_settings.dat")
        guard fm.fileExists(atPath: wgsPath.path) else { return nil }
        do {
            let raw = try Data(contentsOf: wgsPath)
            let parser = NBTParser(data: raw)
            let nbt = try parser.parse()
            // 新版文件结构：root = { DataVersion: ..., data: { seed: ... } }
            if let dataTag = nbt["data"] as? [String: Any],
               let seed = readInt64(dataTag["seed"]) {
                return seed
            }
            return nil
        } catch {
            Logger.shared.error("读取 world_gen_settings.dat 失败: \(error.localizedDescription)")
            return nil
        }
    }
}

