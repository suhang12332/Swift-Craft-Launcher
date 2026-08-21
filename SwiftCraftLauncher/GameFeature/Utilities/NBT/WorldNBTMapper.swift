//
//  WorldNBTMapper.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftNBT

/// NBT parsing utilities for Minecraft world save files (level.dat, world_gen_settings.dat, and others).
enum WorldNBTMapper {
    /// Reads any numeric NBT tag as an `Int64`.
    static func readInt64(_ value: NBTValue?) -> Int64? {
        value?.int64Value
    }

    /// Converts an NBT numeric value to a `Bool` (non-zero is `true`).
    static func readBoolFlag(_ value: NBTValue?) -> Bool {
        value?.boolValue ?? false
    }

    /// Returns a localized game mode string for the given integer value.
    static func mapGameMode(_ value: Int) -> String {
        switch value {
        case 0: return "saveinfo.world.game_mode.survival".localized()
        case 1: return "saveinfo.world.game_mode.creative".localized()
        case 2: return "saveinfo.world.game_mode.adventure".localized()
        case 3: return "saveinfo.world.game_mode.spectator".localized()
        default: return "common.unknown".localized()
        }
    }

    /// Returns a localized difficulty string for the given integer value.
    static func mapDifficulty(_ value: Int) -> String {
        switch value {
        case 0: return "saveinfo.world.difficulty.peaceful".localized()
        case 1: return "saveinfo.world.difficulty.easy".localized()
        case 2: return "saveinfo.world.difficulty.normal".localized()
        case 3: return "saveinfo.world.difficulty.hard".localized()
        default: return "common.unknown".localized()
        }
    }

    /// Returns a localized difficulty string for the given difficulty_settings string value.
    static func mapDifficultyString(_ value: String) -> String {
        switch value.lowercased() {
        case "peaceful": return "saveinfo.world.difficulty.peaceful".localized()
        case "easy": return "saveinfo.world.difficulty.easy".localized()
        case "normal": return "saveinfo.world.difficulty.normal".localized()
        case "hard": return "saveinfo.world.difficulty.hard".localized()
        default: return "common.unknown".localized()
        }
    }

    /// Reads the seed from a level.dat Data tag and an optional world path.
    /// - Priority: RandomSeed, then WorldGenSettings/worldGenSettings.seed,
    ///   then (if `worldPath` is provided) data/minecraft/world_gen_settings.dat -> data.seed.
    static func readSeed(from dataTag: NBTCompound, worldPath: URL?) -> Int64? {
        if let seed = readInt64(dataTag["RandomSeed"]) {
            return seed
        }

        if let worldGenSettings = dataTag["WorldGenSettings"]?.compoundValue,
           let seed = readInt64(worldGenSettings["seed"]) {
            return seed
        }
        if let worldGenSettings = dataTag["worldGenSettings"]?.compoundValue,
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
            let nbt = try NBTDecoder().decode(raw).root
            if let dataTag = nbt["data"]?.compoundValue,
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
