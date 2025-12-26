//
//  LauncherFileFilter.swift
//  SwiftCraftLauncher
//
//

import Foundation

/// 启动器文件过滤器
/// 为每个启动器定义需要过滤的文件名规则（支持正则表达式）
enum LauncherFileFilter {

    /// 获取指定启动器的文件过滤规则
    /// - Parameter launcherType: 启动器类型
    /// - Returns: 文件名过滤规则数组（正则表达式）
    static func getFilterPatterns(for launcherType: ImportLauncherType) -> [String] {
        switch launcherType {
        case .multiMC, .prismLauncher:
            return [
                // MultiMC/PrismLauncher 特定文件
                ".*\\.mmc-pack\\.json$",
                ".*instance\\.cfg$",
                ".*\\.log$",
                "^pack\\.meta$",
            ]

        case .gdLauncher:
            return [
                // GDLauncher 特定文件
                ".*config\\.json$",
                ".*\\.log$",
                "^metadata\\.json$",
            ]

        case .hmcl:
            return [
                // HMCL 特定文件
                ".*config\\.json$",
                ".*\\.log$",
                "^hmclversion\\.json$",
                "^hmclversion\\.cfg$",
                "^usercache\\.json$",
            ]

        case .sjmcLauncher:
            return [
                // SJMCL 特定文件
                ".*sjmclcfg\\.json$",
                ".*\\.log$",
                "^\\d+.*-.*\\.json$",
                "^\\d+.*-.*\\.jar$",
            ]

        case .xmcl:
            return [
                // XMCL 特定文件
                ".*instance\\.json$",
                ".*\\.log$",
                "^metadata\\.json$",
            ]
        }
    }

    /// 检查文件是否应该被过滤
    /// - Parameters:
    ///   - fileName: 文件名（包含相对路径）
    ///   - launcherType: 启动器类型
    /// - Returns: 如果文件应该被过滤（不复制），返回 true
    static func shouldFilter(fileName: String, launcherType: ImportLauncherType) -> Bool {
        let patterns = getFilterPatterns(for: launcherType)

        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let range = NSRange(fileName.startIndex..<fileName.endIndex, in: fileName)

                if regex.firstMatch(in: fileName, options: [], range: range) != nil {
                    Logger.shared.debug("过滤文件: \(fileName) (匹配规则: \(pattern))")
                    return true
                }
            } catch {
                Logger.shared.warning("无效的正则表达式模式: \(pattern), 错误: \(error.localizedDescription)")
            }
        }

        return false
    }

    /// 过滤文件列表
    /// - Parameters:
    ///   - files: 文件 URL 数组
    ///   - sourceDirectory: 源目录（用于计算相对路径）
    ///   - launcherType: 启动器类型
    /// - Returns: 过滤后的文件 URL 数组
    static func filterFiles(
        _ files: [URL],
        sourceDirectory: URL,
        launcherType: ImportLauncherType
    ) -> [URL] {
        return files.filter { fileURL in
            // 计算相对路径
            let relativePath = fileURL.path.replacingOccurrences(
                of: sourceDirectory.path + "/",
                with: ""
            )

            // 检查是否应该过滤
            return !shouldFilter(fileName: relativePath, launcherType: launcherType)
        }
    }
}
