import Foundation
import SwiftUI

/// 语言管理器
/// 只负责语言列表和 bundle
public class LanguageManager {
    /// 当前选中的语言（取 AppleLanguages 数组的第一个）
    public var selectedLanguage: String {
        get {
            UserDefaults.standard.stringArray(forKey: AppConstants.SystemUserDefaultsKeys.appleLanguages)?.first ?? ""
        }
        set {
            if newValue.isEmpty {
                UserDefaults.standard.set([String](), forKey: AppConstants.SystemUserDefaultsKeys.appleLanguages)
            } else {
                var langs = UserDefaults.standard.stringArray(forKey: AppConstants.SystemUserDefaultsKeys.appleLanguages) ?? []
                langs.removeAll { $0 == newValue }
                langs.insert(newValue, at: 0)
                UserDefaults.standard.set(langs, forKey: AppConstants.SystemUserDefaultsKeys.appleLanguages)
            }
        }
    }

    /// 单例实例
    public static let shared = LanguageManager()

    private init() {
        // 如果是首次启动（selectedLanguage为空），则根据系统语言设置默认语言
        if selectedLanguage.isEmpty {
            selectedLanguage = Self.getDefaultLanguage()
        }
    }

    /// 支持的语言列表
    public let languages: [(String, String)] = [
        ("🇨🇳 简体中文", "zh-Hans"),
        ("🇨🇳 繁體中文", "zh-Hant"),
        // ("🇸🇦 العربية", "ar"),
        ("🇩🇰 Dansk", "da"),
        ("🇩🇪 Deutsch", "de"),
        ("🇺🇸 English", "en"),
        ("🇪🇸 Español", "es"),
        ("🇫🇮 Suomi", "fi"),
        ("🇫🇷 Français", "fr"),
        ("🇮🇳 हिन्दी", "hi"),
        ("🇮🇹 Italiano", "it"),
        ("🇯🇵 日本語", "ja"),
        ("🇰🇷 한국어", "ko"),
        ("🇳🇴 Norsk Bokmål", "nb"),
        ("🇳🇱 Nederlands", "nl"),
        ("🇵🇱 Polski", "pl"),
        ("🇵🇹 Português", "pt"),
        ("🇷🇺 Русский", "ru"),
        ("🇸🇪 Svenska", "sv"),
        ("🇹🇭 ไทย", "th"),
        ("🇹🇷 Türkçe", "tr"),
        ("🇻🇳 Tiếng Việt", "vi"),
    ]

    /// 获取当前语言的 Bundle
    public var bundle: Bundle {
        if let path = Bundle.main.path(forResource: selectedLanguage, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }

    public static func getDefaultLanguage() -> String {

        let preferredLanguages = Locale.preferredLanguages

        for preferredLanguage in preferredLanguages {
            // 处理语言代码匹配
            let languageCode = preferredLanguage.prefix(2).lowercased()

            switch languageCode {
            case "zh":
                // 中文：优先简体，其次繁体
                if preferredLanguage.contains("Hans") || preferredLanguage.contains("CN") {
                    return "zh-Hans"
                } else if preferredLanguage.contains("Hant") || preferredLanguage.contains("TW") || preferredLanguage.contains("HK") {
                    return "zh-Hant"
                } else {
                    // 默认简体中文
                    return "zh-Hans"
                }
            case "ar": return "ar"
            case "da": return "da"
            case "de": return "de"
            case "en": return "en"
            case "es": return "es"
            case "fi": return "fi"
            case "fr": return "fr"
            case "hi": return "hi"
            case "it": return "it"
            case "ja": return "ja"
            case "ko": return "ko"
            case "nb", "no": return "nb"  // Norwegian
            case "nl": return "nl"
            case "pl": return "pl"
            case "pt": return "pt"
            case "ru": return "ru"
            case "sv": return "sv"
            case "th": return "th"
            case "tr": return "tr"
            case "vi": return "vi"
            default:
                continue
            }
        }

        // 如果系统语言都不支持，默认使用英文
        return "en"
    }
}

// MARK: - String Localization Extension

extension String {
    /// 获取本地化字符串
    /// - Parameter bundle: 语言包，默认使用当前语言
    /// - Returns: 本地化后的字符串
    public func localized(
        _ bundle: Bundle = LanguageManager.shared.bundle
    ) -> String {
        bundle.localizedString(forKey: self, value: self, table: nil)
    }
}
