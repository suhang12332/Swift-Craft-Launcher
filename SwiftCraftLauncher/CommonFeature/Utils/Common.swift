//
//  Common.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/28.
//

import Foundation
import SwiftUI

extension ServerConnectionStatus {
    var statusColor: Color {
        switch self {
        case .unknown:
            return .secondary
        case .checking:
            return .blue.opacity(0.5)
        case .success:
            return .green
        case .timeout:
            return .red
        case .failed:
            return .red
        }
    }
}

extension URL {
    func forceHTTPS() -> URL? {
        guard
            var components = URLComponents(
                url: self,
                resolvingAgainstBaseURL: true
            )
        else {
            return nil
        }

        // 如果是 HTTP 协议，替换为 HTTPS
        if components.scheme?.lowercased() == "http" {
            components.scheme = "https"
            return components.url
        }

        // 已经是 HTTPS 或其他协议，直接返回
        return self
    }
}
extension String {
    /// 将字符串中的 HTTP URL 转换为 HTTPS
    func httpToHttps() -> String {
        return autoreleasepool {
            guard let url = URL(string: self) else { return self }
            return url.forceHTTPS()?.absoluteString ?? self
        }
    }
}

enum CommonUtil {
    // MARK: - Base64 图片解码工具
    static func imageDataFromBase64(_ base64: String) -> Data? {
        if base64.hasPrefix("data:image") {
            if let base64String = base64.split(separator: ",").last,
                let imageData = Data(base64Encoded: String(base64String)) {
                return imageData
            }
        } else if let imageData = Data(base64Encoded: base64) {
            return imageData
        }
        return nil
    }

    /// 格式化 ISO8601 字符串为相对时间（如"3天前"）
    static func formatRelativeTime(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [
            .withInternetDateTime, .withFractionalSeconds,
        ]
        var date = isoFormatter.date(from: isoString)
        if date == nil {
            // 尝试不带毫秒的格式
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: isoString)
        }
        guard let date = date else { return isoString }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// 解析 `ModrinthProjectDetail.fileName` 中的服务器信息
    static func parseMinecraftJavaServerInfo(from raw: String) -> (address: String, playersText: String?) {
        // 按 `|` 分割并去掉首尾空白
        let parts = raw
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard let address = parts.first, !address.isEmpty else {
            return ("", nil)
        }

        // 只有地址
        if parts.count == 1 {
            return (address, nil)
        }

        // 地址 + 在线
        if parts.count == 2 {
            let online = parts[1]
            guard !online.isEmpty else {
                return (address, nil)
            }
            return (address, "\(online)")
        }

        // 地址 + 在线 + 最大
        let online = parts[1]
        let max = parts[2]

        if !online.isEmpty, !max.isEmpty {
            return (address, "\(online) / \(max)")
        } else if !online.isEmpty {
            return (address, "\(online)")
        } else {
            return (address, nil)
        }
    }

    // MARK: - Minecraft 版本比较和排序

    /// - Returns: -1 表示 version1 < version2，0 相等，1 表示 version1 > version2
    static func compareMinecraftVersions(_ version1: String, _ version2: String) -> Int {
        let components1 = parseVersionComponents(version1)
        let components2 = parseVersionComponents(version2)

        // 比较主版本号
        for i in 0..<max(components1.count, components2.count) {
            let v1 = i < components1.count ? components1[i] : 0
            let v2 = i < components2.count ? components2[i] : 0
            if v1 < v2 {
                return -1
            } else if v1 > v2 {
                return 1
            }
        }

        return 0
    }

    private static func parseVersionComponents(_ version: String) -> [Int] {
        return version.components(separatedBy: ".")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    static func sortMinecraftVersions(_ versions: [String]) -> [String] {
        return versions.sorted { version1, version2 in
            compareMinecraftVersions(version1, version2) > 0
        }
    }

    /// 按基线版本裁剪 Minecraft 版本集合。
    /// 如果集合中存在基线版本，则直接基于当前序列截断，保留基线及其之前的元素；
    /// 如果不存在基线版本，则退回到逐项比较，并保持原始顺序不变。
    static func versionsAtLeast(
        _ versions: [String],
        baseline: String = AppConstants.MinecraftVersions.featureBaseline
    ) -> [String] {
        if let baselineIndex = versions.firstIndex(of: baseline) {
            return Array(versions.prefix(through: baselineIndex))
        }

        return versions.filter {
            compareMinecraftVersions($0, baseline) >= 0
        }
    }

    /// 按基线版本裁剪 Minecraft 版本模型集合。
    /// 如果集合中存在基线版本，则直接基于当前序列截断，保留基线及其之前的元素；
    /// 如果不存在基线版本，则退回到逐项比较，并保持原始顺序不变。
    static func versionsAtLeast<T>(
        _ versions: [T],
        baseline: String = AppConstants.MinecraftVersions.featureBaseline,
        version: (T) -> String
    ) -> [T] {
        if let baselineIndex = versions.firstIndex(where: {
            version($0) == baseline
        }) {
            return Array(versions.prefix(through: baselineIndex))
        }

        return versions.filter {
            compareMinecraftVersions(version($0), baseline) >= 0
        }
    }

    /// 判断单个 Minecraft 版本是否至少为基线版本。
    /// 仅用于没有版本集合上下文时的退回判断。
    static func isVersionAtLeast(_ version: String) -> Bool {
        return compareMinecraftVersions(version, AppConstants.MinecraftVersions.featureBaseline) >= 0
    }

    /// 更新服务器连通性状态（在主线程上设置状态，避免 View 里重复逻辑）
    static func updateServerConnectionStatus(
        for address: String,
        port: Int = 25565,
        timeout: TimeInterval = 5.0,
        setStatus: @escaping (ServerConnectionStatus) -> Void
    ) async {
        guard !address.isEmpty else { return }

        await MainActor.run {
            setStatus(.checking)
        }

        let status = await NetworkUtils.checkServerConnectionStatus(
            address: address,
            port: port,
            timeout: timeout
        )

        await MainActor.run {
            setStatus(status)
        }
    }

    // MARK: - Minecraft Language Mapping

    /// 将启动器语言代码（如 zh-Hans / en / ja）映射为 Minecraft 语言码（如 zh_cn / en_us / ja_jp）
    /// - Parameter launcherLang: 启动器语言代码
    /// - Returns: Minecraft 语言码，默认为 en_us
    static func minecraftLanguageCode(from launcherLang: String) -> String {
        let code = launcherLang.lowercased()

        switch code {
        case "zh-hans", "zh_cn", "zh-cn":
            return "zh_cn"      // 简体中文
        case "zh-hant", "zh_tw", "zh-tw", "zh-hk":
            return "zh_tw"      // 繁体中文

        case "en", "en_us", "en-us", "en-gb":
            return "en_us"      // 英文（默认美式）

        case "de", "de_de", "de-de":
            return "de_de"      // 德语
        case "es", "es_es", "es-es":
            return "es_es"      // 西班牙语
        case "fr", "fr_fr", "fr-fr":
            return "fr_fr"      // 法语
        case "fi", "fi_fi", "fi-fi":
            return "fi_fi"      // 芬兰语
        case "it", "it_it", "it-it":
            return "it_it"      // 意大利语
        case "ja", "ja_jp", "ja-jp":
            return "ja_jp"      // 日语
        case "ko", "ko_kr", "ko-kr":
            return "ko_kr"      // 韩语
        case "nb", "no", "nb_no", "nb-no", "no_no", "no-no":
            return "nb_no"      // 挪威语
        case "nl", "nl_nl", "nl-nl":
            return "nl_nl"      // 荷兰语
        case "pl", "pl_pl", "pl-pl":
            return "pl_pl"      // 波兰语
        case "pt", "pt_br", "pt-br":
            return "pt_br"      // 葡萄牙语（默认巴西葡语）
        case "ru", "ru_ru", "ru-ru":
            return "ru_ru"      // 俄语
        case "sv", "sv_se", "sv-se":
            return "sv_se"      // 瑞典语
        case "th", "th_th", "th-th":
            return "th_th"      // 泰语
        case "tr", "tr_tr", "tr-tr":
            return "tr_tr"      // 土耳其语
        case "vi", "vi_vn", "vi-vn":
            return "vi_vn"      // 越南语

        default:
            // 兜底：用英文
            return "en_us"
        }
    }

    // MARK: - Game Directory Helpers
    /// 根据 gameId 查询游戏并返回对应的实例目录（如果失败则返回 nil）
    static func gameDirectory(for gameId: String) -> URL? {
        let gameDatabase = GameVersionDatabase(dbPath: AppPaths.gameVersionDatabase.path)
        do {
            try? gameDatabase.initialize()
            guard let game = try gameDatabase.getGame(by: gameId) else {
                Logger.shared.warning("无法从数据库找到游戏，无法获取游戏目录: \(gameId)")
                return nil
            }
            return AppPaths.profileDirectory(gameName: game.gameName)
        } catch {
            Logger.shared.error("从数据库查询游戏失败，无法获取游戏目录: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Minecraft Options.txt Helper

    /// 在指定游戏实例的 options.txt 中插入或更新一行 `key:value`
    static func upsertOptionsEntry(gameName: String, key: String, value: String) {
        let optionsURL = AppPaths.optionsFile(gameName: gameName)
        let gameDirectory = optionsURL.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(at: gameDirectory, withIntermediateDirectories: true)

            let fileManager = FileManager.default
            var lines: [String] = []

            if fileManager.fileExists(atPath: optionsURL.path) {
                let content = try String(contentsOf: optionsURL, encoding: .utf8)
                lines = content.components(separatedBy: .newlines)

                var hasKeyLine = false
                lines = lines.map { line in
                    if line.hasPrefix("\(key):") {
                        hasKeyLine = true
                        return "\(key):\(value)"
                    }
                    return line
                }

                if !hasKeyLine {
                    lines.append("\(key):\(value)")
                }
            } else {
                lines = ["\(key):\(value)"]
            }

            let newContent = lines.joined(separator: "\n")
            try newContent.write(to: optionsURL, atomically: true, encoding: .utf8)
        } catch {
            Logger.shared.warning("更新 options.txt 失败（游戏: \(gameName), key: \(key)）: \(error.localizedDescription)")
        }
    }
}
extension ResourceType {
    var overridesSubdirectory: String {
        switch self {
        case .mod:
            return AppConstants.DirectoryNames.mods
        case .datapack:
            return AppConstants.DirectoryNames.datapacks
        case .shader:
            return AppConstants.DirectoryNames.shaderpacks
        case .resourcepack:
            return AppConstants.DirectoryNames.resourcepacks
        case .modpack, .minecraftJavaServer:
            return rawValue
        }
    }
}
