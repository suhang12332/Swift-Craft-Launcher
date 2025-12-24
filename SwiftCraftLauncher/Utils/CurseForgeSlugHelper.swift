import Foundation

/// CurseForge slug 工具
/// 官方规则：^[\w!@$()`.+,"\-']{3,64}$
/// 允许的字符：字母、数字、下划线以及 !@$()`.+,"\-'
/// 长度：3-64 个字符
enum CurseForgeSlugHelper {
    /// 允许的字符集（根据 CurseForge 官方规则）
    private static let allowedCharacters: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "_!@$()`.+,\"-'")
        return set
    }()

    /// 将文本转换为符合 CurseForge 规则的 slug
    /// - Parameter text: 原始文本
    /// - Returns: 符合规则的 slug，如果无法生成有效 slug 则返回空字符串
    static func toSlug(_ text: String) -> String {
        guard !text.isEmpty else { return "" }

        let lowercased = text.lowercased()
        var result = ""
        var lastWasDash = false

        for ch in lowercased {
            // 检查字符是否在允许的字符集中
            if ch.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) {
                result.append(ch)
                lastWasDash = false
            } else {
                // 不允许的字符替换为 `-`，但避免连续多个 `-`
                if !lastWasDash {
                    result.append("-")
                    lastWasDash = true
                }
            }
        }

        // 去掉首尾的 `-`
        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        // 验证长度（3-64）
        if trimmed.count < 3 {
            return ""
        }
        if trimmed.count > 64 {
            return String(trimmed.prefix(64))
        }

        return trimmed
    }

    /// 验证 slug 是否符合 CurseForge 规则
    /// - Parameter slug: 要验证的 slug
    /// - Returns: 是否符合规则
    static func isValid(_ slug: String) -> Bool {
        // 长度检查：3-64
        guard slug.count >= 3 && slug.count <= 64 else {
            return false
        }

        // 字符检查：只允许 allowedCharacters 中的字符
        for scalar in slug.unicodeScalars where !allowedCharacters.contains(scalar) {
            return false
        }

        return true
    }
}
