//
//  WorldNBTMapper.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// NBT parsing utilities for Minecraft world save files (level.dat, world_gen_settings.dat, and others).
enum WorldNBTMapper {
    /// Attempts to convert any NBT numeric type to an `Int64`, supporting Int, Int8, Int16, Int32, UInt, and other variants.
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

    /// Converts an NBT numeric or boolean value to a `Bool` (non-zero is `true`), returning `false` if parsing fails.
    static func readBoolFlag(_ any: Any?) -> Bool {
        guard let any else { return false }
        if let b = any as? Bool { return b }
        if let v = readInt64(any) { return v != 0 }
        return false
    }

    /// Returns a localized game mode string for the given integer value.
    static func mapGameMode(_ value: Int) -> String {
        switch value {
        case 0: return "saveinfo.world.game_mode.survival".localized()
        case 1: return "saveinfo.world.game_mode.creative".localized()
        case 2: return "saveinfo.world.game_mode.adventure".localized()
        case 3: return "saveinfo.world.game_mode.spectator".localized()
        default: return "saveinfo.world.game_mode.unknown".localized()
        }
    }

    /// Returns a localized difficulty string for the given integer value.
    static func mapDifficulty(_ value: Int) -> String {
        switch value {
        case 0: return "saveinfo.world.difficulty.peaceful".localized()
        case 1: return "saveinfo.world.difficulty.easy".localized()
        case 2: return "saveinfo.world.difficulty.normal".localized()
        case 3: return "saveinfo.world.difficulty.hard".localized()
        default: return "saveinfo.world.difficulty.unknown".localized()
        }
    }

    /// Returns a localized difficulty string for the given difficulty_settings string value.
    static func mapDifficultyString(_ value: String) -> String {
        switch value.lowercased() {
        case "peaceful": return "saveinfo.world.difficulty.peaceful".localized()
        case "easy": return "saveinfo.world.difficulty.easy".localized()
        case "normal": return "saveinfo.world.difficulty.normal".localized()
        case "hard": return "saveinfo.world.difficulty.hard".localized()
        default: return "saveinfo.world.difficulty.unknown".localized()
        }
    }

    /// Reads the seed from a level.dat Data tag and an optional world path.
    /// - Priority: RandomSeed, then WorldGenSettings/worldGenSettings.seed,
    ///   then (if `worldPath` is provided) data/minecraft/world_gen_settings.dat -> data.seed.
    static func readSeed(from dataTag: [String: Any], worldPath: URL?) -> Int64? {
        if let seed = readInt64(dataTag["RandomSeed"]) {
            return seed
        }

        if let worldGenSettings = dataTag["WorldGenSettings"] as? [String: Any],
           let seed = readInt64(worldGenSettings["seed"]) {
            return seed
        }
        if let worldGenSettings = dataTag["worldGenSettings"] as? [String: Any],
           let seed = readInt64(worldGenSettings["seed"]) {
            return seed
        }

        guard let worldPath else { return nil }
        return readSeedFromWorldGenSettings(worldPath: worldPath)
    }

    /// Reads the seed from a 26+ format world_gen_settings.dat file at data/minecraft/world_gen_settings.dat.
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
            if let dataTag = nbt["data"] as? [String: Any],
               let seed = readInt64(dataTag["seed"]) {
                return seed
            }
            return nil
        } catch {
            AppLog.game.error("Failed to read world_gen_settings.dat: \(error.localizedDescription)")
            return nil
        }
    }
}
