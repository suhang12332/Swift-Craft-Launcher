//
//  Common.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
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
                resolvingAgainstBaseURL: true,
            )
        else {
            return nil
        }

        if components.scheme?.lowercased() == "http" {
            components.scheme = "https"
            return components.url
        }

        return self
    }
}

extension String {
    /// Converts HTTP URLs in the string to HTTPS.
    func httpToHttps() -> String {
        autoreleasepool {
            guard let url = URL(string: self) else { return self }
            return url.forceHTTPS()?.absoluteString ?? self
        }
    }
}

enum CommonUtil {
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

    /// Formats an ISO 8601 date string into a relative time description.
    static func formatRelativeTime(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [
            .withInternetDateTime, .withFractionalSeconds,
        ]
        var date = isoFormatter.date(from: isoString)
        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: isoString)
        }
        guard let date else { return isoString }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Returns whether the version string represents a snapshot version.
    static func isMinecraftSnapshotVersion(_ version: String) -> Bool {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let isPureNumericVersion = trimmed.range(
            of: #"^\d+(\.\d+)*$"#,
            options: [.regularExpression],
        ) != nil
        return !isPureNumericVersion
    }

    /// Generates the news slug for a release version (e.g., `1.26.1` → `minecraft-java-edition-26-1`).
    static func minecraftReleaseNewsSlug(version: String) -> String {
        let trimmedVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmedVersion.replacingOccurrences(of: ".", with: "-")
        return "minecraft-java-edition-\(normalized)"
    }

    /// Generates the news slug for a snapshot or pre-release version.
    static func minecraftSnapshotNewsSlug(version: String) -> String {
        let base = version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: ".", with: "-")

        if base.range(
            of: #"^\d{2}w\d{2}[a-z]?$"#,
            options: [.regularExpression],
        ) != nil {
            return "minecraft-snapshot-\(base)"
        }

        let normalized = base
            .replacingOccurrences(of: "-rc-", with: "-release-candidate-")
            .replacingOccurrences(of: "-pre-", with: "-pre-release-")
        return "minecraft-\(normalized)"
    }

    /// Parses server address and player info from a `ModrinthProjectDetail.fileName` string.
    static func parseMinecraftJavaServerInfo(from raw: String) -> (address: String, playersText: String?) {
        let parts = raw
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard let address = parts.first, !address.isEmpty else {
            return ("", nil)
        }

        if parts.count == 1 {
            return (address, nil)
        }

        if parts.count == 2 {
            let online = parts[1]
            guard !online.isEmpty else {
                return (address, nil)
            }
            return (address, "\(online)")
        }

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

    /// Compares two Minecraft version strings.
    /// - Returns: `-1` if `version1` < `version2`, `0` if equal, `1` if `version1` > `version2`.
    static func compareMinecraftVersions(_ version1: String, _ version2: String) -> Int {
        let components1 = parseVersionComponents(version1)
        let components2 = parseVersionComponents(version2)

        for i in 0 ..< max(components1.count, components2.count) {
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
        version.components(separatedBy: ".")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    static func sortMinecraftVersions(_ versions: [String]) -> [String] {
        versions.sorted { version1, version2 in
            compareMinecraftVersions(version1, version2) > 0
        }
    }

    /// Returns versions at or above the specified baseline.
    static func versionsAtLeast(
        _ versions: [String],
        baseline: String = AppConstants.MinecraftVersions.featureBaseline,
    ) -> [String] {
        if let baselineIndex = versions.firstIndex(of: baseline) {
            return Array(versions.prefix(through: baselineIndex))
        }

        return versions.filter {
            compareMinecraftVersions($0, baseline) >= 0
        }
    }

    /// Returns model instances at or above the specified baseline version.
    static func versionsAtLeast<T>(
        _ versions: [T],
        baseline: String = AppConstants.MinecraftVersions.featureBaseline,
        version: (T) -> String,
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

    /// Returns whether a Minecraft version meets or exceeds the baseline.
    static func isVersionAtLeast(_ version: String) -> Bool {
        compareMinecraftVersions(version, AppConstants.MinecraftVersions.featureBaseline) >= 0
    }

    /// Checks server connectivity and updates the status on the main thread.
    static func updateServerConnectionStatus(
        for address: String,
        port: Int = 25565,
        timeout: TimeInterval = 5.0,
        setStatus: @escaping (ServerConnectionStatus) -> Void,
    ) async {
        guard !address.isEmpty else { return }

        await MainActor.run {
            setStatus(.checking)
        }

        let status = await NetworkUtils.checkServerConnectionStatus(
            address: address,
            port: port,
            timeout: timeout,
        )

        await MainActor.run {
            setStatus(status)
        }
    }

    /// Maps a launcher language code to the corresponding Minecraft language code.
    /// - Parameter launcherLang: The launcher language code (e.g., `zh-Hans`, `en`).
    /// - Returns: The Minecraft language code, defaulting to `en_us`.
    static func minecraftLanguageCode(from launcherLang: String) -> String {
        let code = launcherLang.lowercased()

        switch code {
        case "zh-hans":
            return "zh_cn"
        case "zh-hant":
            return "zh_tw"
        case "ar":
            return "ar_sa"
        case "da":
            return "da_dk"
        case "en":
            return "en_us"
        case "de":
            return "de_de"
        case "es":
            return "es_es"
        case "fr":
            return "fr_fr"
        case "fi":
            return "fi_fi"
        case "hi":
            return "hi_in"
        case "it":
            return "it_it"
        case "ja":
            return "ja_jp"
        case "ko":
            return "ko_kr"
        case "nb":
            return "nb_no"
        case "nl":
            return "nl_nl"
        case "pl":
            return "pl_pl"
        case "pt":
            return "pt_br"
        case "ru":
            return "ru_ru"
        case "sv":
            return "sv_se"
        case "th":
            return "th_th"
        case "tr":
            return "tr_tr"
        case "vi":
            return "vi_vn"
        default:
            return "en_us"
        }
    }

    /// Returns the instance directory for a game ID, or `nil` if the game is not found.
    static func gameDirectory(for gameId: String) -> URL? {
        let gameDatabase = GameVersionDatabase(dbPath: AppPaths.gameVersionDatabase.path)
        do {
            try? gameDatabase.initialize()
            guard let game = try gameDatabase.getGame(by: gameId) else {
                AppLog.common.error("无法从数据库找到游戏，无法获取游戏目录: \(gameId)")
                return nil
            }
            return AppPaths.profileDirectory(gameName: game.gameName)
        } catch {
            AppLog.common.error("从数据库查询游戏失败，无法获取游戏目录: \(error.localizedDescription)")
            return nil
        }
    }

    /// Inserts or updates a key-value entry in a game instance's `options.txt` file.
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
            AppLog.common.error("更新 options.txt 失败（游戏: \(gameName), key: \(key)）: \(error.localizedDescription)")
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

enum SystemSettings {
    @discardableResult
    static func open(_ paths: [String]) -> Bool {
        for path in paths {
            guard let url = URL(string: path) else { continue }
            if NSWorkspace.shared.open(url) {
                return true
            }
        }
        return false
    }
}
