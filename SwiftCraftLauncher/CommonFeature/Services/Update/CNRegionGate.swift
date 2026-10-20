//
//  CNRegionGate.swift
//  CommonFeature
//

import Foundation
import SwiftUI

/// 中国大陆地区门禁
@MainActor
@Observable
final class CNRegionGate {
    /// 后门键名
    static let plistOverrideKey = "CNRegionGateEnabled"

    /// 门禁开关来源
    enum Override {
        case forced(Bool)
        case notSet

        /// 未设置则默认开启
        var isEnabled: Bool {
            switch self {
            case .forced(let value): return value
            case .notSet: return true
            }
        }
    }

    /// 单例
    static let shared = CNRegionGate()

    /// 缓存检测结果,只调一次网络
    private var cachedOverride: Override?
    private var cachedBlockResult: Override?

    private init() { }

    /// 门禁是否启用
    static var isEnabled: Bool {
        resolveOverride().isEnabled
    }

    /// 是否拦截(优先级:缓存 > 后门键 > 语言 > IP)
    static func isBlocked() async -> Bool {
        guard isEnabled else { return false }
        if let cached = shared.cachedBlockResult { return cached.isEnabled }
        let blocked = await detectBlocked()
        shared.cachedBlockResult = blocked
        AppLog.common.info("CNRegionGate: 检测结果 拦截=\(blocked.isEnabled)")
        return blocked.isEnabled
    }

    // MARK: - 检测

    private static func detectBlocked() async -> Override {
        // 语言命中
        if isSimplifiedChineseLocale() {
            return .forced(true)
        }

        // IP 命中
        let ipService = IPLocationService()
        do {
            let isForeign = try await ipService.isForeignIPThrowing()
            if !isForeign {
                return .forced(true)
            }
        } catch {
            AppLog.common.debug("CNRegionGate: IP检测失败,不拦截: \(error.localizedDescription)")
        }

        return .notSet
    }

    /// 是否简体中文
    private static func isSimplifiedChineseLocale() -> Bool {
        var candidates: [String] = [LanguageManager.getDefaultLanguage()]
        if let languageCode = Locale.current.language.languageCode?.identifier {
            candidates.append(languageCode)
        }
        candidates.append(Locale.current.identifier)

        // 简体前缀
        for candidate in candidates where !candidate.isEmpty {
            if candidate.hasPrefix("zh-Hans") || candidate.hasPrefix("zh_CN") || candidate.hasPrefix("zh-CH") {
                return true
            }
        }

        // 裸 zh 且非港澳台
        if let languageCode = Locale.current.language.languageCode?.identifier, languageCode == "zh" {
            let region = Locale.current.region?.identifier
            let isTraditional = region == "TW" || region == "HK" || region == "MO"
            if !isTraditional {
                return true
            }
        }
        return false
    }

    // MARK: - 后门键解析

    /// 优先级:UserDefaults > Info.plist > 未设置
    static func resolveOverride() -> Override {
        if let cached = shared.cachedOverride { return cached }
        let resolved = readOverride()
        shared.cachedOverride = resolved
        return resolved
    }

    private static func readOverride() -> Override {
        // UserDefaults 命令
        let defaults = UserDefaults.standard
        if defaults.object(forKey: plistOverrideKey) != nil {
            let value = defaults.bool(forKey: plistOverrideKey)
            AppLog.common.info("CNRegionGate: UserDefaults override = \(value)")
            return .forced(value)
        }
        // Info.plist 覆盖
        if let value = Bundle.main.object(forInfoDictionaryKey: plistOverrideKey) as? Bool {
            AppLog.common.info("CNRegionGate: Info.plist override = \(value)")
            return .forced(value)
        }
        // 未设置
        return .notSet
    }
}
