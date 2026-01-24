import Foundation

/// 统一的库过滤工具类
/// 用于消除下载和classpath构建阶段的重复判断逻辑
enum LibraryFilter {

    /// 判断库是否被允许（基于平台规则）
    /// - Parameters:
    ///   - library: 要检查的库
    ///   - minecraftVersion: Minecraft 版本号（可选）
    /// - Returns: 是否允许
    static func isLibraryAllowed(_ library: Library, minecraftVersion: String? = nil) -> Bool {
        // 老版本库无 downloads 或 downloads 无 artifact，无法解析路径，直接不允许
        guard let downloads = library.downloads, downloads.artifact != nil else { return false }
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
        guard library.downloadable, let downloads = library.downloads, downloads.artifact != nil else { return false }
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
