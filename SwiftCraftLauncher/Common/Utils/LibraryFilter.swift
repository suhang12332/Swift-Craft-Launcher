import Foundation

/// 统一的库过滤工具类
/// 统一下载和 classpath 构建的库过滤逻辑
enum LibraryFilter {

    /// 判断库是否被允许（基于平台规则）
    /// - Parameters:
    ///   - library: 要检查的库
    ///   - minecraftVersion: Minecraft 版本号（可选）
    /// - Returns: 是否允许
    static func isLibraryAllowed(_ library: Library, minecraftVersion: String? = nil) -> Bool {
        // 检查系统规则（没有规则或空规则默认允许）
        guard let rules = library.rules, !rules.isEmpty else { return true }
        return MacRuleEvaluator.isAllowed(rules, minecraftVersion: minecraftVersion)
    }

    /// 判断库是否应该下载
    /// - Parameters:
    ///   - library: 要检查的库
    ///   - minecraftVersion: Minecraft 版本号（可选）
    /// - Returns: 是否应该下载
    static func shouldDownloadLibrary(_ library: Library, minecraftVersion: String? = nil) -> Bool {
        guard library.downloadable else { return false }
        return isLibraryAllowed(library, minecraftVersion: minecraftVersion)
    }

    /// 判断库是否应该包含在classpath中
    /// - Parameters:
    ///   - library: 要检查的库
    ///   - minecraftVersion: Minecraft 版本号（可选）
    /// - Returns: 是否应该包含在classpath中
    static func shouldIncludeInClasspath(_ library: Library, minecraftVersion: String? = nil) -> Bool {
        guard library.downloadable == true && library.includeInClasspath == true else {
            return false
        }
        return isLibraryAllowed(library, minecraftVersion: minecraftVersion)
    }
}
