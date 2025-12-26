//
//  LauncherInstanceParser.swift
//  SwiftCraftLauncher
//
//

import Foundation

/// 启动器实例解析器协议
/// 每个启动器都需要实现此协议来解析其实例信息
protocol LauncherInstanceParser {
    /// 启动器类型
    var launcherType: ImportLauncherType { get }

    /// 验证实例是否有效
    /// - Parameter instancePath: 实例文件夹路径
    /// - Returns: 是否为有效实例
    func isValidInstance(at instancePath: URL) -> Bool

    /// 解析实例信息
    /// - Parameters:
    ///   - instancePath: 实例文件夹路径
    ///   - basePath: 启动器基础路径
    /// - Returns: 解析出的实例信息，如果解析失败返回 nil
    func parseInstance(at instancePath: URL, basePath: URL) throws -> ImportInstanceInfo?
}

/// 启动器实例解析器工厂
enum LauncherInstanceParserFactory {
    /// 根据启动器类型创建对应的解析器
    static func createParser(for launcherType: ImportLauncherType) -> LauncherInstanceParser {
        switch launcherType {
        case .multiMC, .prismLauncher:
            return MultiMCInstanceParser(launcherType: launcherType)
        case .gdLauncher:
            return GDLauncherInstanceParser()
        case .xmcl:
            return XMCLInstanceParser()
        case .hmcl, .sjmcLauncher:
            return SJMCLInstanceParser(launcherType: launcherType)
        }
    }
}
