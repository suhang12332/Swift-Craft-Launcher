//
//  WorldDetailSheetViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftNBT

/// View model for the world detail sheet, parsing NBT data from level.dat to display world metadata.
@MainActor
@Observable
final class WorldDetailSheetViewModel {
    private enum LoadError: Error {
        case levelDatNotFound
        case invalidStructure
    }

    let world: WorldInfo
    let gameName: String

    var metadata: WorldDetailMetadata?
    var rawDataTag: NBTCompound?
    var isLoading: Bool = false
    var showRawData: Bool = false

    init(world: WorldInfo, gameName: String) {
        self.world = world
        self.gameName = gameName
    }

    var seed: Int64? {
        metadata?.seed
    }

    var filteredRawData: NBTCompound? {
        guard let raw = rawDataTag else { return nil }

        let displayedKeys: Set = [
            "LevelName", "Version", "DataVersion",
            "GameType", "Difficulty", "hardcore", "allowCommands", "GameRules",
            "LastPlayed", "RandomSeed", "SpawnX", "SpawnY", "SpawnZ",
            "Time", "DayTime", "raining", "thundering", "WorldBorder",
        ]

        let filtered = raw.filter { !displayedKeys.contains($0.key) }
        return filtered.isEmpty ? nil : filtered
    }

    func loadMetadata() async {
        isLoading = true

        do {
            let levelDatPath = world.path.appendingPathComponent("level.dat")
            let worldGenSettingsPath = world.path
                .appendingPathComponent("data", isDirectory: true)
                .appendingPathComponent("minecraft", isDirectory: true)
                .appendingPathComponent("world_gen_settings.dat")
            let pathForBackground = levelDatPath

            let (dataTag, seedOverride): (NBTCompound, Int64?) = try {
                guard FileManager.default.fileExists(atPath: pathForBackground.path) else {
                    throw LoadError.levelDatNotFound
                }
                let data = try Data(contentsOf: pathForBackground)
                let document = try NBTDecoder().decode(data)
                guard let tag = document.root["Data"]?.compoundValue else {
                    throw LoadError.invalidStructure
                }

                var seed: Int64?
                if FileManager.default.fileExists(atPath: worldGenSettingsPath.path) {
                    let wgsData = try Data(contentsOf: worldGenSettingsPath)
                    let wgsDocument = try NBTDecoder().decode(wgsData)
                    if let dataTag = wgsDocument.root["data"]?.compoundValue,
                       let s = dataTag["seed"]?.int64Value {
                        seed = s
                    }
                }

                return (tag, seed)
            }()

            let parsedMetadata = parseWorldDetail(
                from: dataTag,
                folderName: world.name,
                path: world.path,
                seedOverride: seedOverride,
            )

            rawDataTag = dataTag
            metadata = parsedMetadata
            isLoading = false
        } catch LoadError.levelDatNotFound {
            isLoading = false
            DIContainer.shared.core.errorHandler.handle(GlobalError.fileSystem(
                i18nKey: "saveinfo.world.detail.error.level_dat_not_found",
                level: .silent,
            ))
        } catch LoadError.invalidStructure {
            isLoading = false
            DIContainer.shared.core.errorHandler.handle(GlobalError.fileSystem(
                i18nKey: "saveinfo.world.detail.error.invalid_structure",
                level: .silent,
            ))
        } catch {
            AppLog.game.error("Failed to load world details: \(error.localizedDescription)")
            isLoading = false
            DIContainer.shared.core.errorHandler.handle(GlobalError.from(error))
        }
    }

    private func parseWorldDetail(
        from dataTag: NBTCompound,
        folderName: String,
        path: URL,
        seedOverride: Int64?,
    ) -> WorldDetailMetadata {
        let levelName = dataTag["LevelName"]?.stringValue ?? folderName

        var lastPlayedDate: Date?
        if let ts = dataTag["LastPlayed"]?.int64Value {
            lastPlayedDate = Date(timeIntervalSince1970: TimeInterval(ts) / 1000.0)
        }

        var gameMode = "common.unknown".localized()
        if let gt = dataTag["GameType"]?.int64Value {
            gameMode = WorldNBTMapper.mapGameMode(Int(gt))
        }

        var difficulty = "common.unknown".localized()
        if let diff = dataTag["Difficulty"]?.int64Value {
            difficulty = WorldNBTMapper.mapDifficulty(Int(diff))
        } else if let ds = dataTag["difficulty_settings"]?.compoundValue,
                  let diffStr = ds["difficulty"]?.stringValue {
            difficulty = WorldNBTMapper.mapDifficultyString(diffStr)
        }

        let hardcore: Bool = {
            if let ds = dataTag["difficulty_settings"]?.compoundValue {
                return WorldNBTMapper.readBoolFlag(ds["hardcore"])
            }
            return WorldNBTMapper.readBoolFlag(dataTag["hardcore"])
        }()
        let cheats: Bool = WorldNBTMapper.readBoolFlag(dataTag["allowCommands"])

        var versionName: String?
        var versionId: Int?
        if let versionTag = dataTag["Version"]?.compoundValue {
            versionName = versionTag["Name"]?.stringValue
            if let id = versionTag["Id"]?.int64Value {
                versionId = Int(id)
            }
        }

        var dataVersion: Int?
        if let dv = dataTag["DataVersion"]?.int64Value {
            dataVersion = Int(dv)
        }

        var seed: Int64? = seedOverride
        if seed == nil {
            seed = WorldNBTMapper.readSeed(from: dataTag, worldPath: path)
        }

        var spawn: String?
        if let x = dataTag["SpawnX"]?.int64Value,
           let y = dataTag["SpawnY"]?.int64Value,
           let z = dataTag["SpawnZ"]?.int64Value {
            spawn = "\(x), \(y), \(z)"
        } else if let spawnTag = dataTag["spawn"]?.compoundValue,
                  let pos = spawnTag["pos"]?.listValue,
                  pos.count >= 3,
                  let x = pos[0].int64Value,
                  let y = pos[1].int64Value,
                  let z = pos[2].int64Value {
            if let dim = spawnTag["dimension"]?.stringValue, !dim.isEmpty {
                spawn = "\(x), \(y), \(z) (\(dim))"
            } else {
                spawn = "\(x), \(y), \(z)"
            }
        }

        let time = dataTag["Time"]?.int64Value
        let dayTime = dataTag["DayTime"]?.int64Value

        var weather: String?
        if let rainingFlag = dataTag["raining"] {
            let raining = WorldNBTMapper.readBoolFlag(rainingFlag)
            weather = raining ? "saveinfo.world.weather.rain".localized() : "saveinfo.world.weather.clear".localized()
        }
        if let thunderingFlag = dataTag["thundering"] {
            let thundering = WorldNBTMapper.readBoolFlag(thunderingFlag)
            let t = thundering ? "saveinfo.world.weather.thunderstorm".localized() : nil
            if let t {
                weather = weather.map { "\($0), \(t)" } ?? t
            }
        }

        var worldBorder: String?
        if let wb = dataTag["WorldBorder"]?.compoundValue {
            worldBorder = WorldNBTMapper.flattenCompound(wb).map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
        }

        var gameRules: [String]?
        if let gr = dataTag["GameRules"]?.compoundValue {
            gameRules = WorldNBTMapper.flattenCompound(gr).map { "\($0.key)=\($0.value)" }.sorted()
        }

        return WorldDetailMetadata(
            levelName: levelName,
            folderName: folderName,
            path: path,
            lastPlayed: lastPlayedDate,
            gameMode: gameMode,
            difficulty: difficulty,
            hardcore: hardcore,
            cheats: cheats,
            versionName: versionName,
            versionId: versionId,
            dataVersion: dataVersion,
            seed: seed,
            spawn: spawn,
            time: time,
            dayTime: dayTime,
            weather: weather,
            worldBorder: worldBorder,
            gameRules: gameRules,
        )
    }
}
