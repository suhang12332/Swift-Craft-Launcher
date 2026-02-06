//
//  WorldDetailSheetView.swift
//  SwiftCraftLauncher
//
//  Created by su (via AI assistant) on 2025/1/29.
//

import SwiftUI

private enum WorldDetailLoadError: Error {
    case levelDatNotFound
    case invalidStructure
}

/// 世界详细信息视图（读取 level.dat）
struct WorldDetailSheetView: View {
    // MARK: - Properties
    let world: WorldInfo
    let gameName: String
    @Environment(\.dismiss)
    private var dismiss

    @State private var metadata: WorldDetailMetadata?
    @State private var rawDataTag: [String: Any]? // 原始 Data 标签，尽可能多展示数据
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showRawData = false // 控制是否显示原始数据

    // MARK: - Body
    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: { bodyView },
            footer: { footerView }
        )
        .frame(minWidth: 500, minHeight: 400)
        .task {
            await loadMetadata()
        }
        .alert("common.error".localized(), isPresented: $showError) {
            Button("common.ok".localized(), role: .cancel) { }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Text(world.name)
                .font(.headline)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Body View
    private var bodyView: some View {
        Group {
            if isLoading {
                loadingView
            } else if let metadata = metadata {
                metadataContentView(metadata: metadata)
            } else {
                errorView
            }
        }
    }

    private var loadingView: some View {
        VStack {
            ProgressView().controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("saveinfo.world.detail.load.failed".localized())
                .font(.headline)
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func metadataContentView(metadata: WorldDetailMetadata) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 24) {
                    // 基本信息
                    infoSection(title: "saveinfo.world.detail.section.basic".localized()) {
                        infoRow(label: "saveinfo.world.detail.label.level_name".localized(), value: metadata.levelName)
                        infoRow(label: "saveinfo.world.detail.label.folder_name".localized(), value: metadata.folderName)
                        if let versionName = metadata.versionName {
                            infoRow(label: "saveinfo.world.detail.label.game_version".localized(), value: versionName)
                        }
                        if let versionId = metadata.versionId {
                            infoRow(label: "saveinfo.world.detail.label.version_id".localized(), value: "\(versionId)")
                        }
                        if let dataVersion = metadata.dataVersion {
                            infoRow(label: "saveinfo.world.detail.label.data_version".localized(), value: "\(dataVersion)")
                        }
                    }

                    // 游戏设置
                    infoSection(title: "saveinfo.world.detail.section.game_settings".localized()) {
                        infoRow(label: "saveinfo.world.detail.label.game_mode".localized(), value: metadata.gameMode)
                        infoRow(label: "saveinfo.world.detail.label.difficulty".localized(), value: metadata.difficulty)
                        infoRow(label: "saveinfo.world.detail.label.hardcore".localized(), value: metadata.hardcore ? "common.yes".localized() : "common.no".localized())
                        infoRow(label: "saveinfo.world.detail.label.cheats".localized(), value: metadata.cheats ? "common.yes".localized() : "common.no".localized())
                        if let seed = metadata.seed {
                            infoRow(label: "saveinfo.world.detail.label.seed".localized(), value: "\(seed)")
                        }
                    }
                }

                // 其他信息
                infoSection(title: "saveinfo.world.detail.section.other".localized()) {
                    if let lastPlayed = metadata.lastPlayed {
                        infoRow(label: "saveinfo.world.detail.label.last_played".localized(), value: formatDate(lastPlayed))
                    }
                    if let spawn = metadata.spawn {
                        infoRow(label: "saveinfo.world.detail.label.spawn".localized(), value: spawn)
                    }
                    if let time = metadata.time {
                        infoRow(label: "saveinfo.world.detail.label.time".localized(), value: "\(time)")
                    }
                    if let dayTime = metadata.dayTime {
                        infoRow(label: "saveinfo.world.detail.label.day_time".localized(), value: "\(dayTime)")
                    }
                    if let weather = metadata.weather {
                        infoRow(label: "saveinfo.world.detail.label.weather".localized(), value: weather)
                    }
                    if let border = metadata.worldBorder {
                        infoRow(label: "saveinfo.world.detail.label.world_border".localized(), value: border, isMultiline: true)
                    }
                }

                HStack(alignment: .center, spacing: 12) {
                    Text("saveinfo.world.detail.label.world_path".localized() + ":")
                        .font(.headline)
                    Button {
                        // 在 Finder 中打开文件位置
                        NSWorkspace.shared.selectFile(metadata.path.path, inFileViewerRootedAtPath: "")
                    } label: {
                        PathBreadcrumbView(path: metadata.path.path)
                            .frame(maxWidth: .infinity, alignment: .leading).font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 原始数据切换按钮
                if let raw = rawDataTag {
                    let displayedKeys: Set<String> = [
                        "LevelName", "Version", "DataVersion",
                        "GameType", "Difficulty", "hardcore", "allowCommands", "GameRules",
                        "LastPlayed", "RandomSeed", "SpawnX", "SpawnY", "SpawnZ",
                        "Time", "DayTime", "raining", "thundering", "WorldBorder",
                    ]

                    let filteredRaw = raw.filter { !displayedKeys.contains($0.key) }

                    if !filteredRaw.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                withAnimation {
                                    showRawData.toggle()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: showRawData ? "chevron.down" : "chevron.right")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text("saveinfo.world.detail.toggle.detailed_info".localized())
                                        .font(.headline)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)

                            if showRawData {
                                NBTStructureView(data: filteredRaw)
//                                infoSection(title: "saveinfo.world.detail.section.detailed_info".localized()) {
//
//                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func infoSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 10)
            content()
        }
    }

    private func infoRow(label: String, value: String, isMultiline: Bool = false) -> some View {
        HStack(alignment: isMultiline ? .top : .center, spacing: 12) {
            Text(label + ":")
                .font(.subheadline)
                .foregroundColor(.secondary)
            if isMultiline {
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Footer View
    private var footerView: some View {
        HStack {
            Label {
                Text(world.path.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } icon: {
                Image(systemName: "folder.fill")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: 200, alignment: .leading)

            Spacer()

            Label {
                Text(gameName)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } icon: {
                Image(systemName: "gamecontroller")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: 300, alignment: .trailing)
        }
    }

    // MARK: - Helper Methods
    private func loadMetadata() async {
        isLoading = true
        errorMessage = nil

        do {
            let levelDatPath = world.path.appendingPathComponent("level.dat")
            let worldGenSettingsPath = world.path
                .appendingPathComponent("data", isDirectory: true)
                .appendingPathComponent("minecraft", isDirectory: true)
                .appendingPathComponent("world_gen_settings.dat")
            let pathForBackground = levelDatPath

        let (dataTag, seedOverride): ([String: Any], Int64?) = try await Task.detached(priority: .userInitiated) {
                guard FileManager.default.fileExists(atPath: pathForBackground.path) else {
                    throw WorldDetailLoadError.levelDatNotFound
                }
                let data = try Data(contentsOf: pathForBackground)
                let parser = NBTParser(data: data)
                let nbtData = try parser.parse()
                guard let tag = nbtData["Data"] as? [String: Any] else {
                    throw WorldDetailLoadError.invalidStructure
                }

                // 26+ 新版存档：seed 拆到 data/minecraft/world_gen_settings.dat
                var seed: Int64?
                if FileManager.default.fileExists(atPath: worldGenSettingsPath.path) {
                    do {
                        let wgsData = try Data(contentsOf: worldGenSettingsPath)
                        let wgsParser = NBTParser(data: wgsData)
                        let wgsNBT = try wgsParser.parse()
                        if let dataTag = wgsNBT["data"] as? [String: Any],
                           let s = WorldNBTMapper.readInt64(dataTag["seed"]) {
                            seed = s
                        }
                    } catch {
                        // 读取失败不影响 level.dat 的展示
                    }
                }

                return (tag, seed)
            }.value

            let metadata = parseWorldDetail(from: dataTag, folderName: world.name, path: world.path, seedOverride: seedOverride)
            await MainActor.run {
                self.rawDataTag = dataTag
                self.metadata = metadata
                self.isLoading = false
            }
        } catch WorldDetailLoadError.levelDatNotFound {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "saveinfo.world.detail.error.level_dat_not_found".localized()
                self.showError = true
            }
        } catch WorldDetailLoadError.invalidStructure {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "saveinfo.world.detail.error.invalid_structure".localized()
                self.showError = true
            }
        } catch {
            Logger.shared.error("加载世界详细信息失败: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = String(format: "saveinfo.world.detail.error.load_failed".localized(), error.localizedDescription)
                self.showError = true
            }
        }
    }

    private func parseWorldDetail(from dataTag: [String: Any], folderName: String, path: URL, seedOverride: Int64?) -> WorldDetailMetadata {
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
            if let v = WorldNBTMapper.readBoolFlag(dataTag["hardcore"]) { return v }
            if let ds = dataTag["difficulty_settings"] as? [String: Any],
               let v = WorldNBTMapper.readBoolFlag(ds["hardcore"]) { return v }
            return false
        }()
        let cheats: Bool = WorldNBTMapper.readBoolFlag(dataTag["allowCommands"]) ?? false

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
            let raining = WorldNBTMapper.readBoolFlag(rainingFlag) ?? false
            weather = raining ? "saveinfo.world.weather.rain".localized() : "saveinfo.world.weather.clear".localized()
        }
        if let thunderingFlag = dataTag["thundering"] {
            let thundering = WorldNBTMapper.readBoolFlag(thunderingFlag) ?? false
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }

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

// MARK: - NBT 结构视图（保持原始嵌套结构）
struct NBTStructureView: View {
    let data: [String: Any]
    @State private var expandedKeys: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(data.keys.sorted()), id: \.self) { key in
                if let value = data[key] {
                    NBTEntryView(
                        key: key,
                        value: value,
                        expandedKeys: $expandedKeys,
                        indentLevel: 0,
                        fullKey: key
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct NBTEntryView: View {
    let key: String
    let value: Any
    @Binding var expandedKeys: Set<String>
    let indentLevel: Int
    let fullKey: String
    private let indentWidth: CGFloat = 20
    @State private var isHovered = false

    init(key: String, value: Any, expandedKeys: Binding<Set<String>>, indentLevel: Int, fullKey: String? = nil) {
        self.key = key
        self.value = value
        self._expandedKeys = expandedKeys
        self.indentLevel = indentLevel
        self.fullKey = fullKey ?? key
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let dict = value as? [String: Any] {
                // 字典类型
                NBTDisclosureButton(
                    isExpanded: expandedKeys.contains(fullKey),
                    label: key,
                    suffix: "{\(dict.count)}",
                    indentLevel: indentLevel,
                    isHovered: $isHovered
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expandedKeys.contains(fullKey) {
                            expandedKeys.remove(fullKey)
                        } else {
                            expandedKeys.insert(fullKey)
                        }
                    }
                }

                if expandedKeys.contains(fullKey) {
                    ForEach(Array(dict.keys.sorted()), id: \.self) { subKey in
                        if let subValue = dict[subKey] {
                            Self(
                                key: subKey,
                                value: subValue,
                                expandedKeys: $expandedKeys,
                                indentLevel: indentLevel + 1,
                                fullKey: "\(fullKey).\(subKey)"
                            )
                        }
                    }
                }
            } else if let array = value as? [Any] {
                // 数组类型
                NBTDisclosureButton(
                    isExpanded: expandedKeys.contains(fullKey),
                    label: key,
                    suffix: "[\(array.count)]",
                    indentLevel: indentLevel,
                    isHovered: $isHovered
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expandedKeys.contains(fullKey) {
                            expandedKeys.remove(fullKey)
                        } else {
                            expandedKeys.insert(fullKey)
                        }
                    }
                }

                if expandedKeys.contains(fullKey) {
                    ForEach(Array(array.enumerated()), id: \.offset) { index, item in
                        let arrayItemKey = "\(fullKey)[\(index)]"
                        if let itemDict = item as? [String: Any] {
                            Self(
                                key: "[\(index)]",
                                value: itemDict,
                                expandedKeys: $expandedKeys,
                                indentLevel: indentLevel + 1,
                                fullKey: arrayItemKey
                            )
                        } else {
                            NBTValueRow(
                                label: "[\(index)]",
                                value: formatNBTValue(item),
                                indentLevel: indentLevel + 1
                            )
                        }
                    }
                }
            } else {
                // 基本类型
                NBTValueRow(
                    label: key,
                    value: formatNBTValue(value),
                    indentLevel: indentLevel
                )
            }
        }
    }

    private func formatNBTValue(_ value: Any) -> String {
        if let v = value as? String { return "\"\(v)\"" }
        if let v = value as? Bool { return v ? "true" : "false" }
        if let v = value as? Int8 { return "\(v)b" }
        if let v = value as? Int16 { return "\(v)s" }
        if let v = value as? Int32 { return "\(v)" }
        if let v = value as? Int64 { return "\(v)L" }
        if let v = value as? Int { return "\(v)" }
        if let v = value as? Double { return "\(v)d" }
        if let v = value as? Float { return "\(v)f" }
        if let v = value as? Data { return "Data(\(v.count) bytes)" }
        if let v = value as? URL { return v.path }
        return String(describing: value)
    }
}

// MARK: - macOS 风格的组件
struct NBTDisclosureButton: View {
    let isExpanded: Bool
    let label: String
    let suffix: String
    let indentLevel: Int
    @Binding var isHovered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 14, alignment: .leading)
                    .contentShape(Rectangle())

                Text(label)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(suffix)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .padding(.leading, CGFloat(indentLevel) * 20)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct NBTValueRow: View {
    let label: String
    let value: String
    let indentLevel: Int
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Text(label + ":")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .trailing)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .padding(.leading, CGFloat(indentLevel) * 20 + 14)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.secondary.opacity(0.08) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - 世界详细信息模型
struct WorldDetailMetadata {
    let levelName: String
    let folderName: String
    let path: URL
    let lastPlayed: Date?
    let gameMode: String
    let difficulty: String
    let hardcore: Bool
    let cheats: Bool
    let versionName: String?
    let versionId: Int?
    let dataVersion: Int?
    let seed: Int64?
    let spawn: String?
    let time: Int64?
    let dayTime: Int64?
    let weather: String?
    let worldBorder: String?
    let gameRules: [String]?
}
