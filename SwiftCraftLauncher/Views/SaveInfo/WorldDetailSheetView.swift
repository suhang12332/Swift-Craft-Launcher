//
//  WorldDetailSheetView.swift
//  SwiftCraftLauncher
//
//  Created by su (via AI assistant) on 2025/1/29.
//

import SwiftUI

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
                        if let gameRules = metadata.gameRules, !gameRules.isEmpty {
                            infoRow(label: "saveinfo.world.detail.label.game_rules".localized(), value: gameRules.joined(separator: ", "), isMultiline: true)
                        }
                    }
                }

                // 其他信息
                infoSection(title: "saveinfo.world.detail.section.other".localized()) {
                    if let lastPlayed = metadata.lastPlayed {
                        infoRow(label: "saveinfo.world.detail.label.last_played".localized(), value: formatDate(lastPlayed))
                    }
                    if let seed = metadata.seed {
                        infoRow(label: "saveinfo.world.detail.label.seed".localized(), value: "\(seed)")
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
                    infoRow(label: "saveinfo.world.detail.label.world_path".localized(), value: metadata.path.path, isMultiline: true)
                }

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
            guard FileManager.default.fileExists(atPath: levelDatPath.path) else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "saveinfo.world.detail.error.level_dat_not_found".localized()
                    self.showError = true
                }
                return
            }

            let data = try Data(contentsOf: levelDatPath)
            let parser = NBTParser(data: data)
            let nbtData = try parser.parse()

            guard let dataTag = nbtData["Data"] as? [String: Any] else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "saveinfo.world.detail.error.invalid_structure".localized()
                    self.showError = true
                }
                return
            }

            let metadata = parseWorldDetail(from: dataTag, folderName: world.name, path: world.path)

            await MainActor.run {
                self.rawDataTag = dataTag
                self.metadata = metadata
                self.isLoading = false
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

    private func parseWorldDetail(from dataTag: [String: Any], folderName: String, path: URL) -> WorldDetailMetadata {
        let levelName = (dataTag["LevelName"] as? String) ?? folderName

        // LastPlayed 为毫秒时间戳（Long）
        var lastPlayedDate: Date?
        if let ts = dataTag["LastPlayed"] {
            if let v = ts as? Int64 {
                lastPlayedDate = Date(timeIntervalSince1970: TimeInterval(v) / 1000.0)
            } else if let v = ts as? Int {
                lastPlayedDate = Date(timeIntervalSince1970: TimeInterval(v) / 1000.0)
            }
        }

        // GameType: 0 生存, 1 创造, 2 冒险, 3 旁观
        var gameMode = "saveinfo.world.game_mode.unknown".localized()
        if let gt = dataTag["GameType"] as? Int {
            gameMode = mapGameMode(gt)
        } else if let gt32 = dataTag["GameType"] as? Int32 {
            gameMode = mapGameMode(Int(gt32))
        }

        // Difficulty: 0 和平, 1 简单, 2 普通, 3 困难
        var difficulty = "saveinfo.world.difficulty.unknown".localized()
        if let diff = dataTag["Difficulty"] as? Int {
            difficulty = mapDifficulty(diff)
        } else if let diff8 = dataTag["Difficulty"] as? Int8 {
            difficulty = mapDifficulty(Int(diff8))
        }

        let hardcore = (dataTag["hardcore"] as? Int8 ?? 0) != 0
        let cheats = (dataTag["allowCommands"] as? Int8 ?? 0) != 0

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

        var seed: Int64?
        if let s = dataTag["RandomSeed"] as? Int64 {
            seed = s
        } else if let s = dataTag["RandomSeed"] as? Int {
            seed = Int64(s)
        }

        var spawn: String?
        if let x = readInt64(dataTag["SpawnX"]), let y = readInt64(dataTag["SpawnY"]), let z = readInt64(dataTag["SpawnZ"]) {
            spawn = "\(x), \(y), \(z)"
        }

        let time = readInt64(dataTag["Time"])
        let dayTime = readInt64(dataTag["DayTime"])

        var weather: String?
        if let raining = readInt64(dataTag["raining"]) {
            weather = (raining != 0) ? "saveinfo.world.weather.rain".localized() : "saveinfo.world.weather.clear".localized()
        }
        if let thundering = readInt64(dataTag["thundering"]) {
            let t = (thundering != 0) ? "saveinfo.world.weather.thunderstorm".localized() : nil
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

    private func mapGameMode(_ value: Int) -> String {
        switch value {
        case 0: return "saveinfo.world.game_mode.survival".localized()
        case 1: return "saveinfo.world.game_mode.creative".localized()
        case 2: return "saveinfo.world.game_mode.adventure".localized()
        case 3: return "saveinfo.world.game_mode.spectator".localized()
        default: return "saveinfo.world.game_mode.unknown".localized()
        }
    }

    private func mapDifficulty(_ value: Int) -> String {
        switch value {
        case 0: return "saveinfo.world.difficulty.peaceful".localized()
        case 1: return "saveinfo.world.difficulty.easy".localized()
        case 2: return "saveinfo.world.difficulty.normal".localized()
        case 3: return "saveinfo.world.difficulty.hard".localized()
        default: return "saveinfo.world.difficulty.unknown".localized()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }

    private func readInt64(_ any: Any?) -> Int64? {
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
