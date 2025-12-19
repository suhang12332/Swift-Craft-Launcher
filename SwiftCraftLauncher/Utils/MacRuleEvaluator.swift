import Foundation

// MARK: - Mac 规则评估器

enum MacOS: String {
    case osx = "osx"
    case osxArm64 = "osx-arm64"
    case osxX86_64 = "osx-x86_64"

    static func fromJavaArch(_ javaArch: String) -> Self {
        let arch = javaArch.lowercased()
        if arch.contains("aarch64") {
            return .osxArm64
        } else if arch.contains("x86_64") || arch.contains("amd64") {
            return .osxX86_64
        } else {
            return .osx
        }
    }
}

enum RuleAction: String {
    case allow = "allow"
    case disallow = "disallow"
}

struct MacRule {
    let action: RuleAction
    let os: MacOS?
}

enum MacRuleEvaluator {

    /// 获取当前 Java 架构
    static func getCurrentJavaArch() -> String {
        #if os(macOS)
        return Architecture.current.javaArch
        #else
        return "x86_64"
        #endif
    }

    /// 检查是否为低版本 Minecraft (1.19 以下)
    /// - Parameter version: Minecraft 版本号
    /// - Returns: 是否为低版本
    static func isLowVersion(_ version: String) -> Bool {
        let versionComponents = version.split(separator: ".").compactMap { Int($0) }
        guard versionComponents.count >= 2 else { return false }

        let major = versionComponents[0]
        let minor = versionComponents[1]

        // 1.19 以下版本使用严格架构匹配
        return major < 1 || (major == 1 && minor < 19)
    }

    /// 获取当前平台支持的 macOS 标识符列表（按优先级排序）
    /// - Parameter minecraftVersion: Minecraft 版本号（可选）
    /// - Returns: 支持的 macOS 标识符列表
    static func getSupportedMacOSIdentifiers(minecraftVersion: String? = nil) -> [String] {
        #if os(macOS)
        let isLowVersion = minecraftVersion.map { Self.isLowVersion($0) } ?? false

        return Architecture.current.macOSIdentifiers(isLowVersion: isLowVersion)
        #elseif os(Linux)
        return ["linux"]
        #elseif os(Windows)
        return ["windows"]
        #else
        return []
        #endif
    }

    /// 检查给定的标识符是否被当前平台支持
    /// - Parameters:
    ///   - identifier: 要检查的标识符
    ///   - minecraftVersion: Minecraft 版本号（可选）
    /// - Returns: 是否支持
    static func isPlatformIdentifierSupported(_ identifier: String, minecraftVersion: String? = nil) -> Bool {
        return getSupportedMacOSIdentifiers(minecraftVersion: minecraftVersion).contains(identifier)
    }

    /// 从 Minecraft 的 Rule 结构转换为 MacRule
    static func convertFromMinecraftRules(_ rules: [Rule]) -> [MacRule] {
        return rules.compactMap { rule in
            guard let action = RuleAction(rawValue: rule.action) else { return nil }

            let macOS: MacOS?
            if let osName = rule.os?.name, let validMacOS = MacOS(rawValue: osName) {
                macOS = validMacOS
            } else if rule.os?.name != nil {
                return nil // 非 macOS 规则
            } else {
                macOS = nil // 无 OS 限制
            }

            return MacRule(action: action, os: macOS)
        }
    }

    /// 评估规则是否允许
    static func isAllowed(_ rules: [Rule], minecraftVersion: String? = nil) -> Bool {
        guard !rules.isEmpty else { return true }

        let macRules = convertFromMinecraftRules(rules)

        // 如果原始规则不为空但转换后为空，说明都是非 macOS 规则
        if macRules.isEmpty {
            return false
        }

        // 获取当前平台支持的标识符列表
        let supportedIdentifiers = getSupportedMacOSIdentifiers(minecraftVersion: minecraftVersion)

        // 根据支持的标识符获取适用的规则（按优先级排序）
        var applicableRules: [MacRule] = []

        // 优先查找高优先级的规则
        for identifier in supportedIdentifiers {
            let macOS = MacOS(rawValue: identifier)
            let matchingRules = macRules.filter { rule in
                rule.os == nil || rule.os == macOS
            }
            if !matchingRules.isEmpty {
                applicableRules = matchingRules
                break
            }
        }

        // 如果没有找到匹配的规则，使用无 OS 限制的规则
        if applicableRules.isEmpty {
            applicableRules = macRules.filter { $0.os == nil }
        }

        guard !applicableRules.isEmpty else { return false }

        // 优先检查 disallow 规则
        if applicableRules.contains(where: { $0.action == .disallow }) {
            return false
        }

        // 检查 allow 规则
        return applicableRules.contains { $0.action == .allow }
    }
}
