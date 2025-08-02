import Foundation
import SwiftUI

/// 语言管理器
/// 只负责语言列表和 bundle
public class LanguageManager {
    // 新增：启动器工作目录
    @AppStorage("selectedLanguage") public var selectedLanguage: String = "" {
        didSet {  }
    }

    /// 单例实例
    public static let shared = LanguageManager()

    private init() {
        // 如果是首次启动（selectedLanguage为空），则根据系统语言设置默认语言
        if selectedLanguage.isEmpty {
            selectedLanguage = LanguageManager.getDefaultLanguage()
        }
    }

    /// 支持的语言列表
    public let languages: [(String, String)] = [

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

        // 获取系统首选语言列表
        let preferredLanguages = Locale.preferredLanguages

        // 遍历系统首选语言，找到第一个支持的语言
        for preferredLanguage in preferredLanguages {
            // 处理语言代码匹配
            let languageCode = preferredLanguage.prefix(2).lowercased()

            switch languageCode {
            case "zh":
                // 中文：优先简体，其次繁体
                if preferredLanguage.contains("Hans")
                    || preferredLanguage.contains("CN")
                {
                    return "zh-Hans"
                } else if preferredLanguage.contains("Hant")
                    || preferredLanguage.contains("TW")
                    || preferredLanguage.contains("HK")
                {
                    return "zh-Hant"
                } else {
                    // 默认简体中文
                    return "zh-Hans"
                }
            case "en":
                return "en"
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
    public func localized(_ bundle: Bundle = LanguageManager.shared.bundle)
        -> String
    {
        NSLocalizedString(self, bundle: bundle, comment: "")
    }
}
