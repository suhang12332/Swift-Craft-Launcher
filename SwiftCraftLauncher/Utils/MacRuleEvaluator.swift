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
        #if arch(arm64)
        return "aarch64"
        #else
        return "x86_64"
        #endif
        #else
        return "x86_64"
        #endif
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
    static func isAllowed(_ rules: [Rule]) -> Bool {
        guard !rules.isEmpty else { return true }

        let macRules = convertFromMinecraftRules(rules)

        // 如果原始规则不为空但转换后为空，说明都是非 macOS 规则
        if macRules.isEmpty {
            return false
        }

        let currentOS = MacOS.fromJavaArch(getCurrentJavaArch())

        // 获取适用的规则：匹配当前架构的规则，或通用规则（无 OS 限制）
        let applicableRules = macRules.filter { rule in
            rule.os == nil || rule.os == currentOS || rule.os == .osx
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
