//
//  Common.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/28.
//

import Foundation
import SwiftUI

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
}
