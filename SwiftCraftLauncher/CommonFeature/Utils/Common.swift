//
//  Common.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/28.
//

import Foundation
import SwiftUI
import AppKit
import ImageIO

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

    /// 判断 Minecraft 版本是否至少为基线版本
    static func isVersionAtLeast(_ version: String) -> Bool {
        return compareMinecraftVersions(version, AppConstants.MinecraftVersions.featureBaseline) >= 0
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

extension Notification.Name {
    static let gameCrashed = Notification.Name("SwiftCraftLauncher.GameCrashed")
}

enum ImageLoadingUtil {
    static func downsampledImage(
        at url: URL,
        maxPixelSize: CGFloat,
        scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0
    ) -> NSImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return downsampledImage(from: imageSource, maxPixelSize: maxPixelSize, scale: scale)
    }

    static func downsampledImage(
        data: Data,
        maxPixelSize: CGFloat,
        scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0
    ) -> NSImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        return downsampledImage(from: imageSource, maxPixelSize: maxPixelSize, scale: scale)
    }

    static func imageMemoryCost(_ image: NSImage) -> Int {
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cgImage.bytesPerRow * cgImage.height
        }
        let size = image.size
        return Int(size.width * size.height * 4)
    }

    private static func downsampledImage(
        from imageSource: CGImageSource,
        maxPixelSize: CGFloat,
        scale: CGFloat
    ) -> NSImage? {
        let targetPixelSize = max(1, Int(maxPixelSize * max(1.0, scale)))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: targetPixelSize,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
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
        case .modpack:
            return rawValue
        }
    }
}
