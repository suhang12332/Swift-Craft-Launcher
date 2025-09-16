import Foundation

/// 统一的库过滤工具类
/// 用于消除下载和classpath构建阶段的重复判断逻辑
enum LibraryFilter {

    /// 判断库是否被允许（基于平台规则）
    /// - Parameter library: 要检查的库
    /// - Returns: 是否允许
    static func isLibraryAllowed(_ library: Library) -> Bool {
        // 检查系统规则（没有规则或空规则默认允许）
        guard let rules = library.rules, !rules.isEmpty else { return true }
        return MacRuleEvaluator.isAllowed(rules)
    }

    /// 判断库是否应该下载
    /// - Parameter library: 要检查的库
    /// - Returns: 是否应该下载
    static func shouldDownloadLibrary(_ library: Library) -> Bool {
        guard library.downloadable else { return false }
        return isLibraryAllowed(library)
    }

    /// 判断库是否应该包含在classpath中
    /// - Parameter library: 要检查的库
    /// - Returns: 是否应该包含在classpath中
    static func shouldIncludeInClasspath(_ library: Library) -> Bool {
        guard library.downloadable == true && library.includeInClasspath == true else {
            return false
        }
        return isLibraryAllowed(library)
    }
}
