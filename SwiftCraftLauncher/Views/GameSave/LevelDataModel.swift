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

            let dataTag = structure.tag
            // Logger.shared.debug("成功读取结构，字段: \(structure.tag.contents.keys)")

            var parsed: [String: String] = [:]

            let keysToShow: Set<String> = [
                "LevelName", "GameType", "Difficulty", "hardcore", "allowCommands",
                "Time", "DayTime", "LastPlayed",
                "seed", "WorldGenSettings",
                "raining", "thundering", "rainTime", "thunderTime",
                "Player", "GameRules"
            ]

            guard let outer = dataTag[""] as? NBTCompound,
                  let inner = outer["Data"] as? NBTCompound else {
                self.errorMessage = "error.data.tag.notfound".localized()
                Logger.shared.error("未找到名为 Data 的标签（请确认结构是否为有效的 level.dat 文件）: \(filePath)")
                return
            }

            for (key, value) in inner.contents where keysToShow.contains(key) {
                if key == "Player", let playerCompound = value as? NBTCompound {
                    // 只展示指定的重要玩家字段
                    let importantPlayerFields = [
                        "Health": "生命值",
                        "XpLevel": "经验等级",
                        "XpTotal": "总经验值",
                        "XpP": "当前等级进度",
                        "Dimension": "当前维度",
                        "foodLevel": "饥饿值",
                        "foodSaturationLevel": "食物饱和度",
                        "foodExhaustionLevel": "疲劳度"
                    ]

                    for (pKey, pVal) in playerCompound.contents {
                        if importantPlayerFields.keys.contains(pKey) {
                            let displayName = importantPlayerFields[pKey] ?? pKey
                            parsed["Player.\(displayName)"] = formatNBTValue(pVal, key: "Player.\(pKey)")
                        }

                        // 特殊处理坐标，分解为X、Y、Z
                        if pKey == "Pos", let posList = pVal as? NBTList, posList.elements.count == 3 {
                            if let x = posList.elements[0] as? NBTDouble,
                               let y = posList.elements[1] as? NBTDouble,
                               let z = posList.elements[2] as? NBTDouble {
                                // 优化坐标显示格式为 [X, Y, Z]
                                let xCoord = String(format: "%.1f", x)
                                let yCoord = String(format: "%.1f", y)
                                let zCoord = String(format: "%.1f", z)
                                parsed["Player.位置坐标"] = "[\(xCoord), \(yCoord), \(zCoord)]"
                            }
                        }
                    }
                } else if key == "GameRules", let rulesCompound = value as? NBTCompound {
                    // 只展示 keepInventory 游戏规则
                    if let keepInventoryValue = rulesCompound["keepInventory"] {
                        parsed["GameRules.keepInventory"] = formatNBTValue(keepInventoryValue, key: "GameRules.keepInventory")
                    }
                } else if key == "WorldGenSettings", let worldGenCompound = value as? NBTCompound {
                    // 处理 WorldGenSettings 中的种子字段
                    if let seedValue = worldGenCompound["seed"] {
                        parsed["seed"] = formatNBTValue(seedValue, key: "seed")
                    }
                } else {
                    parsed[key] = formatNBTValue(value, key: key)
                }
            }
            Logger.shared.debug("已提取字段: \(parsed.keys.joined(separator: ", "))")

            DispatchQueue.main.async {
                self.levelData = parsed
                self.errorMessage = nil
            }

        } catch {
            Logger.shared.error("level.dat 读取失败: \(filePath)，错误: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func loadLevelDat() {
        // 兼容旧接口，默认路径
        loadLevelDat(from: "/Users/su/Downloads/level.dat")
    }
    
    private func formatMappedValue(key: String, value: String) -> String {
        switch key {
        case "GameType":
            switch value {
            case "0": return "生存模式 (Survival)"
            case "1": return "创造模式 (Creative)"
            case "2": return "极限模式 (Hardcore)"
            case "3": return "旁观者 (Spectator)"
            default: return value
            }
        case "Difficulty":
            switch value {
            case "0": return "和平 (Peaceful)"
            case "1": return "简单 (Easy)"
            case "2": return "普通 (Normal)"
            case "3": return "困难 (Hard)"
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
            case let list as NBTList: return "[\(list.elements.count) items]"
            case let compound as NBTCompound:
                let inner = compound.contents.map { "\($0.key): \(formatNBTValue($0.value))" }.joined(separator: ", ")
                return "{\(inner)}"
            default: return String(describing: value)
            }
        }()

        if let k = key {
            let lastKey = k.components(separatedBy: ".").last ?? k

            // 时间字段友好显示
            if lastKey == "LastPlayed", let millis = Int64(stringValue) {
                let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
                return date.formatted(.relative(presentation: .named))
            }

            if lastKey == "Time" || lastKey == "DayTime" {
                if let ticks = Int64(stringValue) {
                    let seconds = Double(ticks) / 20.0
                    let formatter = DateComponentsFormatter()
                    formatter.allowedUnits = [.day, .hour, .minute, .second]
                    formatter.unitsStyle = .abbreviated
                    formatter.maximumUnitCount = 2
                    return formatter.string(from: seconds) ?? "\(Int(seconds))秒"
                }
            }

            // 种子字段友好显示
            if lastKey == "seed" {
                if let seedValue = Int64(stringValue) {
                    return "\(seedValue)"
                }
            }

            // 玩家字段友好显示
            if lastKey == "生命值" {
                if let health = Float(stringValue) {
                    return String(format: "%.1f", health)
                }
            }

            if lastKey == "位置坐标" {
                // 保持原始格式显示
                return stringValue
            }

            if lastKey == "当前维度" {
                // 维度名称中文显示
                switch stringValue {
                case "minecraft:overworld": return "主世界"
                case "minecraft:the_nether": return "下界"
                case "minecraft:the_end": return "末地"
                default: return stringValue.replacingOccurrences(of: "minecraft:", with: "")
                }
            }
            
            if lastKey == "Dimension" {
                // 维度名称中文显示
                switch stringValue {
                case "minecraft:overworld": return "主世界"
                case "minecraft:the_nether": return "下界"
                case "minecraft:the_end": return "末地"
                default: return stringValue.replacingOccurrences(of: "minecraft:", with: "")
                }
            }
            
            // 天气状态友好显示
            if lastKey == "raining" {
                return stringValue == "1" ? "正在下雨" : "晴天"
            }
            
            if lastKey == "thundering" {
                return stringValue == "1" ? "正在打雷" : "无雷暴"
            }

            // 其他映射
            return formatMappedValue(key: lastKey, value: stringValue)
        } else {
            return stringValue
        }
    }
}
