import Foundation
import SwiftUI

/// 语言管理器
/// 只负责语言列表与当前生效语言读取（不在 App 内修改语言）
public class LanguageManager {
    private static let languageFlagByCode: [String: String] = [
        "zh-Hans": "🇨🇳",
        "zh-Hant": "🇨🇳",
        "ar": "🇸🇦",
        "da": "🇩🇰",
        "de": "🇩🇪",
        "en": "🇺🇸/🇬🇧",
        "es": "🇪🇸",
        "fi": "🇫🇮",
        "fr": "🇫🇷",
        "hi": "🇮🇳",
        "it": "🇮🇹",
        "ja": "🇯🇵",
        "ko": "🇰🇷",
        "nb": "🇳🇴",
        "nl": "🇳🇱",
        "pl": "🇵🇱",
        "pt": "🇵🇹/🇧🇷",
        "ru": "🇷🇺",
        "sv": "🇸🇪",
        "th": "🇹🇭",
        "tr": "🇹🇷",
        "vi": "🇻🇳",
    ]

    private static func flagEmoji(for code: String) -> String? {
        if let flag = languageFlagByCode[code] { return flag }
        if let base = code.split(separator: "-").first.map(String.init),
           let flag = languageFlagByCode[base] {
            return flag
        }
        return nil
    }

    public var selectedLanguage: String {
        Self.getDefaultLanguage()
    }

    /// 单例实例
    public static let shared = LanguageManager()

    private init() {}

    /// 获取当前对本 App 生效的语言 code（系统自动匹配/回退后，并限制在 App 支持的本地化中）。
    public static func getDefaultLanguage() -> String {
        Bundle.main.preferredLocalizations.first ?? "en"
    }

    /// 获取语言显示名称（用于 UI 展示）。
    /// - Parameters:
    ///   - code: 语言/地区标识（例如 "en"、"zh-Hans"、"ja"）
    ///   - locale: 用于显示的 Locale（默认当前系统 Locale）
    /// - Returns: 尽可能本地化的显示名；如果无法解析则回退到英语显示名。
    public static func displayName(for code: String, locale: Locale = .current) -> String {
        let name = locale.localizedString(forIdentifier: code)
            ?? locale.localizedString(forIdentifier: "en")
            ?? "English"

        if let flag = flagEmoji(for: code) {
            return "\(flag) \(name)"
        }
        return name
    }

    /// 当前生效语言的显示名称（用于 UI 展示）。
    public var selectedLanguageDisplayName: String {
        Self.displayName(for: selectedLanguage)
    }
}

// MARK: - String Localization Extension

extension String {
    /// 获取本地化字符串
    /// - Parameter bundle: 默认使用系统解析后的主 bundle
    /// - Returns: 本地化后的字符串
    public func localized(
        _ bundle: Bundle = .main
    ) -> String {
        bundle.localizedString(forKey: self, value: self, table: nil)
    }
}
