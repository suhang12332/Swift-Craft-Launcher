import Foundation

@MainActor
final class WorldDetailSheetViewModel: ObservableObject {

    // MARK: - Types

    private enum LoadError: Error {
        case levelDatNotFound
        case invalidStructure
    }

    // MARK: - Input

    let world: WorldInfo
    let gameName: String

    // MARK: - Output state

    @Published var metadata: WorldDetailMetadata?
    @Published var rawDataTag: [String: Any]?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var showRawData: Bool = false

    // MARK: - Init

    init(world: WorldInfo, gameName: String) {
        self.world = world
        self.gameName = gameName
    }

    // MARK: - Derived

    var seed: Int64? {
        metadata?.seed
    }

    var filteredRawData: [String: Any]? {
        guard let raw = rawDataTag else { return nil }

        let displayedKeys: Set<String> = [
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
        errorMessage = nil
        showError = false

        do {
            let levelDatPath = world.path.appendingPathComponent("level.dat")
            let worldGenSettingsPath = world.path
                .appendingPathComponent("data", isDirectory: true)
                .appendingPathComponent("minecraft", isDirectory: true)
                .appendingPathComponent("world_gen_settings.dat")
            let pathForBackground = levelDatPath

            let (dataTag, seedOverride): ([String: Any], Int64?) = try await Task.detached(priority: .userInitiated) {
                guard FileManager.default.fileExists(atPath: pathForBackground.path) else {
                    throw LoadError.levelDatNotFound
                }
                let data = try Data(contentsOf: pathForBackground)
                let parser = NBTParser(data: data)
                let nbtData = try parser.parse()
                guard let tag = nbtData["Data"] as? [String: Any] else {
                    throw LoadError.invalidStructure
                }

                // 26+ 新版存档：seed 拆到 data/minecraft/world_gen_settings.dat
                var seed: Int64?
                if FileManager.default.fileExists(atPath: worldGenSettingsPath.path) {
                    let wgsData = try Data(contentsOf: worldGenSettingsPath)
                    let wgsParser = NBTParser(data: wgsData)
                    let wgsNBT = try wgsParser.parse()
                    if let dataTag = wgsNBT["data"] as? [String: Any],
                       let s = WorldNBTMapper.readInt64(dataTag["seed"]) {
                        seed = s
                    }
                }

                return (tag, seed)
            }.value

            let parsedMetadata = parseWorldDetail(
                from: dataTag,
                folderName: world.name,
                path: world.path,
                seedOverride: seedOverride
            )

            self.rawDataTag = dataTag
            self.metadata = parsedMetadata
            self.isLoading = false
        } catch LoadError.levelDatNotFound {
            isLoading = false
            errorMessage = "saveinfo.world.detail.error.level_dat_not_found".localized()
            showError = true
        } catch LoadError.invalidStructure {
            isLoading = false
            errorMessage = "saveinfo.world.detail.error.invalid_structure".localized()
            showError = true
        } catch {
            Logger.shared.error("加载世界详细信息失败: \(error.localizedDescription)")
            isLoading = false
            errorMessage = String(
                format: "saveinfo.world.detail.error.load_failed".localized(),
                error.localizedDescription
            )
            showError = true
        }
    }

    // MARK: - Parsing

    private func parseWorldDetail(
        from dataTag: [String: Any],
        folderName: String,
        path: URL,
        seedOverride: Int64?
    ) -> WorldDetailMetadata {
        let levelName = (dataTag["LevelName"] as? String) ?? folderName

        // LastPlayed 为毫秒时间戳（Long），兼容 Int/Int64 等类型
        var lastPlayedDate: Date?
        if let ts = WorldNBTMapper.readInt64(dataTag["LastPlayed"]) {
            lastPlayedDate = Date(timeIntervalSince1970: TimeInterval(ts) / 1000.0)
        }

        // GameType: 0 生存, 1 创造, 2 冒险, 3 旁观
        var gameMode = "saveinfo.world.game_mode.unknown".localized()
        if let gt = WorldNBTMapper.readInt64(dataTag["GameType"]) {
            gameMode = WorldNBTMapper.mapGameMode(Int(gt))
        }

        // Difficulty: 旧版为数值，新版（26+）常为 difficulty_settings.difficulty 字符串
        var difficulty = "saveinfo.world.difficulty.unknown".localized()
        if let diff = WorldNBTMapper.readInt64(dataTag["Difficulty"]) {
            difficulty = WorldNBTMapper.mapDifficulty(Int(diff))
        } else if let ds = dataTag["difficulty_settings"] as? [String: Any],
                  let diffStr = ds["difficulty"] as? String {
            difficulty = WorldNBTMapper.mapDifficultyString(diffStr)
        }

        // 极限/作弊标志在新版可能是 byte 或 bool，这里统一为「非 0 即 true」
        let hardcore: Bool = {
            if let ds = dataTag["difficulty_settings"] as? [String: Any] {
                return WorldNBTMapper.readBoolFlag(ds["hardcore"])
            }
            return WorldNBTMapper.readBoolFlag(dataTag["hardcore"])
        }()
        let cheats: Bool = WorldNBTMapper.readBoolFlag(dataTag["allowCommands"])

        var versionName: String?
        var versionId: Int?
        if let versionTag = dataTag["Version"] as? [String: Any] {
            versionName = versionTag["Name"] as? String
            if let id = versionTag["Id"] as? Int {
                versionId = id
            } else if let id32 = versionTag["Id"] as? Int32 {
                versionId = Int(id32)
            }
        }

        var dataVersion: Int?
        if let dv = dataTag["DataVersion"] as? Int {
            dataVersion = dv
        } else if let dv32 = dataTag["DataVersion"] as? Int32 {
            dataVersion = Int(dv32)
        }

        // 种子：26+ 优先 world_gen_settings.dat，其次 level.dat 的 RandomSeed / WorldGenSettings.seed
        var seed: Int64? = seedOverride
        if seed == nil {
            seed = WorldNBTMapper.readSeed(from: dataTag, worldPath: path)
        }

        var spawn: String?
        if let x = WorldNBTMapper.readInt64(dataTag["SpawnX"]),
           let y = WorldNBTMapper.readInt64(dataTag["SpawnY"]),
           let z = WorldNBTMapper.readInt64(dataTag["SpawnZ"]) {
            spawn = "\(x), \(y), \(z)"
        } else if let spawnTag = dataTag["spawn"] as? [String: Any],
                  let pos = spawnTag["pos"] as? [Any],
                  pos.count >= 3,
                  let x = WorldNBTMapper.readInt64(pos[0]),
                  let y = WorldNBTMapper.readInt64(pos[1]),
                  let z = WorldNBTMapper.readInt64(pos[2]) {
            // 26+ 新版存档：spawn.pos = [x, y, z]，同时可能带 dimension/yaw/pitch
            if let dim = spawnTag["dimension"] as? String, !dim.isEmpty {
                spawn = "\(x), \(y), \(z) (\(dim))"
            } else {
                spawn = "\(x), \(y), \(z)"
            }
        }

        let time = WorldNBTMapper.readInt64(dataTag["Time"])
        let dayTime = WorldNBTMapper.readInt64(dataTag["DayTime"])

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
        if let wb = dataTag["WorldBorder"] as? [String: Any] {
            worldBorder = flattenNBTDictionary(wb, prefix: "").map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
        }

        var gameRules: [String]?
        if let gr = dataTag["GameRules"] as? [String: Any] {
            gameRules = flattenNBTDictionary(gr, prefix: "").map { "\($0.key)=\($0.value)" }.sorted()
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
            gameRules: gameRules
        )
    }

    // MARK: - NBT helpers

    private func flattenNBTDictionary(_ dict: [String: Any], prefix: String = "") -> [String: String] {
        var result: [String: String] = [:]
        for (k, v) in dict {
            let key = prefix.isEmpty ? k : "\(prefix).\(k)"
            if let sub = v as? [String: Any] {
                let nested = flattenNBTDictionary(sub, prefix: key)
                for (nk, nv) in nested { result[nk] = nv }
            } else if let arr = v as? [Any] {
                result[key] = arr.map { stringifyNBTValue($0) }.joined(separator: ", ")
            } else {
                result[key] = stringifyNBTValue(v)
            }
        }
        return result
    }

    private func stringifyNBTValue(_ value: Any) -> String {
        if let v = value as? String { return v }
        if let v = value as? Bool { return v ? "true" : "false" }
        if let v = value as? Int8 { return "\(v)" }
        if let v = value as? Int16 { return "\(v)" }
        if let v = value as? Int32 { return "\(v)" }
        if let v = value as? Int64 { return "\(v)" }
        if let v = value as? Int { return "\(v)" }
        if let v = value as? Double { return "\(v)" }
        if let v = value as? Float { return "\(v)" }
        if let v = value as? Data { return "Data(\(v.count) bytes)" }
        if let v = value as? URL { return v.path }
        return String(describing: value)
    }
}
