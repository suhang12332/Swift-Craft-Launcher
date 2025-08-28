//
//  LevelDataModel.swift
//  MLauncherGame
//
//  Created by su on 2025/7/15.
//

import Foundation
import MinecraftNBT

class LevelDataModel: ObservableObject {
    @Published var levelData: [String: String] = [:]
    @Published var errorMessage: String? = nil

    private var nbtStructure: NBTStructure?
    private var dataCompound: NBTCompound?

    deinit {
        levelData.removeAll(keepingCapacity: false)
        errorMessage = nil
        nbtStructure = nil
        dataCompound = nil
    }

    func loadLevelDat(from filePath: String) {
        let fileURL = URL(fileURLWithPath: filePath)

        do {
            let data = try Data(contentsOf: fileURL)
            Logger.shared.debug("读取文件: \(filePath)，大小: \(data.count) 字节")

            guard let structure = NBTStructure(compressed: data) else {
                self.errorMessage = "error.nbt.read.failed".localized()
                Logger.shared.error("无法读取 NBT 数据（解压失败）: \(filePath)")
                return
            }

            guard let outer = structure.tag[""] as? NBTCompound,
                let inner = outer["Data"] as? NBTCompound
            else {
                self.errorMessage = "error.data.tag.notfound".localized()
                Logger.shared.error(
                    "未找到名为 Data 的标签（请确认结构是否为有效的 level.dat 文件）: \(filePath)"
                )
                return
            }

            // 存储NBT结构以供后续使用
            self.nbtStructure = structure
            self.dataCompound = inner

            // 只加载基础信息，其他数据按需加载
            loadBasicInfo()
        } catch {
            Logger.shared.error(
                "level.dat 读取失败: \(filePath)，错误: \(error.localizedDescription)"
            )
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // 加载基础信息（世界名称、游戏模式等）
    private func loadBasicInfo() {
        guard let inner = dataCompound else { return }

        let basicKeys: Set<String> = [
            "LevelName", "GameType", "Difficulty", "hardcore", "allowCommands",
        ]

        var basicData: [String: String] = [:]

        for key in basicKeys {
            if let value = inner[key] {
                basicData[key] = formatNBTValue(value, key: key)
            }
        }

        DispatchQueue.main.async {
            self.levelData = basicData
            self.errorMessage = nil
        }
    }

    // 按需加载世界设置数据
    func loadWorldSettingsData() {
        guard let inner = dataCompound else { return }

        let worldSettingsKeys: Set<String> = [
            "Time", "DayTime", "LastPlayed", "seed", "WorldGenSettings",
            "GameRules",
        ]

        var worldSettingsData: [String: String] = [:]

        for key in worldSettingsKeys {
            if let value = inner[key] {
                if key == "GameRules", let rulesCompound = value as? NBTCompound
                {
                    // 只展示 keepInventory 游戏规则
                    if let keepInventoryValue = rulesCompound["keepInventory"] {
                        worldSettingsData["GameRules.keepInventory"] =
                            formatNBTValue(
                                keepInventoryValue,
                                key: "GameRules.keepInventory"
                            )
                    }
                } else if key == "WorldGenSettings",
                    let worldGenCompound = value as? NBTCompound
                {
                    // 处理 WorldGenSettings 中的种子字段
                    if let seedValue = worldGenCompound["seed"] {
                        worldSettingsData["seed"] = formatNBTValue(
                            seedValue,
                            key: "seed"
                        )
                    }
                } else {
                    worldSettingsData[key] = formatNBTValue(value, key: key)
                }
            }
        }

        DispatchQueue.main.async {
            self.levelData.merge(worldSettingsData) { _, new in new }
        }
    }

    // 按需加载玩家数据
    func loadPlayerData() {
        guard let inner = dataCompound else { return }

        if let playerCompound = inner["Player"] as? NBTCompound {
            let importantPlayerFields = [
                "Health": "player.health".localized(),
                "XpLevel": "player.xp.level".localized(),
                "XpTotal": "player.xp.total".localized(),
                "XpP": "player.xp.progress".localized(),
                "Dimension": "player.dimension".localized(),
                "foodLevel": "player.food.level".localized(),
                "foodSaturationLevel": "player.food.saturation".localized(),
                "foodExhaustionLevel": "player.food.exhaustion".localized(),
            ]

            var playerData: [String: String] = [:]

            for (pKey, pVal) in playerCompound.contents {
                if importantPlayerFields.keys.contains(pKey) {
                    let displayName = importantPlayerFields[pKey] ?? pKey
                    playerData["Player.\(displayName)"] = formatNBTValue(
                        pVal,
                        key: "Player.\(pKey)"
                    )
                }

                // 特殊处理坐标，分解为X、Y、Z
                if pKey == "Pos", let posList = pVal as? NBTList,
                    posList.elements.count == 3
                {
                    if let x = posList.elements[0] as? NBTDouble,
                        let y = posList.elements[1] as? NBTDouble,
                        let z = posList.elements[2] as? NBTDouble
                    {
                        // 优化坐标显示格式为 [X, Y, Z]
                        let xCoord = String(format: "%.1f", x)
                        let yCoord = String(format: "%.1f", y)
                        let zCoord = String(format: "%.1f", z)
                        playerData["Player.\("player.position".localized())"] =
                            "[\(xCoord), \(yCoord), \(zCoord)]"
                    }
                }
            }

            DispatchQueue.main.async {
                self.levelData.merge(playerData) { _, new in new }
            }
        }
    }

    // 按需加载天气数据
    func loadWeatherData() {
        guard let inner = dataCompound else { return }

        // 只提取实际使用的天气字段
        let weatherKeys: Set<String> = [
            "raining", "thundering",
        ]

        var weatherData: [String: String] = [:]

        for key in weatherKeys {
            if let value = inner[key] {
                weatherData[key] = formatNBTValue(value, key: key)
            }
        }

        DispatchQueue.main.async {
            self.levelData.merge(weatherData) { _, new in new }
        }
    }

    private func formatMappedValue(key: String, value: String) -> String {
        switch key {
        case "GameType":
            switch value {
            case "0": return "survival".localized()
            case "1": return "creative".localized()
            case "2": return "hardcore".localized()
            case "3": return "spectator".localized()
            default: return value
            }
        case "Difficulty":
            switch value {
            case "0": return "peaceful".localized()
            case "1": return "easy".localized()
            case "2": return "normal".localized()
            case "3": return "hard".localized()
            default: return value
            }

        default:
            return value
        }
    }

    func formatNBTValue(_ value: any NBTTag, key: String? = nil) -> String {
        // 先转换为字符串
        let stringValue: String = {
            switch value {
            case let byte as NBTByte: return "\(byte)"
            case let short as NBTShort: return "\(short)"
            case let int as NBTInt: return "\(int)"
            case let long as NBTLong: return "\(long)"
            case let float as NBTFloat: return "\(float)"
            case let double as NBTDouble: return "\(double)"
            case let string as NBTString: return string
            case let list as NBTList:
                return "[\(list.elements.count) \("nbt.items".localized())]"
            case let compound as NBTCompound:
                let inner = compound.contents.map {
                    "\($0.key): \(formatNBTValue($0.value))"
                }
                .joined(separator: ", ")
                return "{\(inner)}"
            default: return String(describing: value)
            }
        }()

        if let k = key {
            let lastKey = k.components(separatedBy: ".").last ?? k

            // 时间字段友好显示
            if lastKey == "LastPlayed", let millis = Int64(stringValue) {
                let date = Date(
                    timeIntervalSince1970: TimeInterval(millis) / 1000
                )
                return date.formatted(.relative(presentation: .named))
            }

            if lastKey == "Time" || lastKey == "DayTime" {
                if let ticks = Int64(stringValue) {
                    let seconds = Double(ticks) / 20.0
                    let formatter = DateComponentsFormatter()
                    formatter.allowedUnits = [.day, .hour, .minute, .second]
                    formatter.unitsStyle = .abbreviated
                    formatter.maximumUnitCount = 2
                    return formatter.string(from: seconds)
                        ?? "\(Int(seconds))\("time.second".localized())"
                }
            }

            // 种子字段友好显示
            if lastKey == "seed" {
                if let seedValue = Int64(stringValue) {
                    return "\(seedValue)"
                }
            }

            // 玩家字段友好显示
            if lastKey == "player.health".localized() {
                if let health = Float(stringValue) {
                    return String(format: "%.1f", health)
                }
            }

            if lastKey == "player.position".localized() {
                // 保持原始格式显示
                return stringValue
            }

            if lastKey == "player.dimension".localized() {
                // 维度名称中文显示
                switch stringValue {
                case "minecraft:overworld": return "main.world".localized()
                case "minecraft:the_nether": return "nether".localized()
                case "minecraft:the_end": return "the.end".localized()
                default:
                    return stringValue.replacingOccurrences(
                        of: "minecraft:",
                        with: ""
                    )
                }
            }

            if lastKey == "Dimension" {
                // 维度名称中文显示
                switch stringValue {
                case "minecraft:overworld": return "main.world".localized()
                case "minecraft:the_nether": return "nether".localized()
                case "minecraft:the_end": return "the.end".localized()
                default:
                    return stringValue.replacingOccurrences(
                        of: "minecraft:",
                        with: ""
                    )
                }
            }

            // 天气状态友好显示
            if lastKey == "raining" {
                return stringValue == "1"
                    ? "raining".localized() : "clear".localized()
            }

            if lastKey == "thundering" {
                return stringValue == "1"
                    ? "thundering".localized() : "no.thunder".localized()
            }

            // 其他映射
            return formatMappedValue(key: lastKey, value: stringValue)
        } else {
            return stringValue
        }
    }
}
