//
//  PlaceholderInstanceParser.swift
//  SwiftCraftLauncher
//
//

import Foundation

/// 占位符实例解析器
/// 用于尚未实现解析逻辑的启动器
struct PlaceholderInstanceParser: LauncherInstanceParser {
    let launcherType: ImportLauncherType
    
    init(launcherType: ImportLauncherType) {
        self.launcherType = launcherType
    }
    
    func isValidInstance(at instancePath: URL) -> Bool {
        // 暂未实现，返回 false
        return false
    }
    
    func parseInstance(at instancePath: URL, basePath: URL) throws -> ImportInstanceInfo? {
        // 暂未实现，抛出错误
        throw LauncherImportError.parserNotImplemented(launcherType: launcherType.rawValue)
    }
}

/// 启动器导入错误
enum LauncherImportError: LocalizedError {
    case parserNotImplemented(launcherType: String)
    
    var errorDescription: String? {
        switch self {
        case .parserNotImplemented(let launcherType):
            return String(
                format: "launcher.import.error.parser_not_implemented".localized(),
                launcherType
            )
        }
    }
}

