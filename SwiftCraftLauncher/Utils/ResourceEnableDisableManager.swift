//
//  ResourceEnableDisableManager.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/28.
//

import Foundation

/// 资源启用/禁用状态管理器
/// 负责管理本地资源的启用和禁用状态（通过 .disable 后缀）
enum ResourceEnableDisableManager {
    /// 检查资源是否被禁用
    /// - Parameter fileName: 文件名
    /// - Returns: 是否被禁用
    static func isDisabled(fileName: String?) -> Bool {
        guard let fileName = fileName else { return false }
        return fileName.hasSuffix(".disable")
    }

    /// 切换资源的启用/禁用状态
    /// - Parameters:
    ///   - fileName: 当前文件名
    ///   - resourceDir: 资源目录
    /// - Returns: 新的文件名，如果操作失败则返回 nil
    /// - Throws: 文件操作错误
    static func toggleDisableState(
        fileName: String,
        resourceDir: URL
    ) throws -> String {
        let fileManager = FileManager.default
        let currentURL = resourceDir.appendingPathComponent(fileName)
        let targetFileName: String

        let isCurrentlyDisabled = fileName.hasSuffix(".disable")
        if isCurrentlyDisabled {
            guard fileName.hasSuffix(".disable") else {
                throw NSError(
                    domain: "ResourceEnableDisableManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "启用资源失败：文件后缀不包含 .disable"]
                )
            }
            targetFileName = String(fileName.dropLast(".disable".count))
        } else {
            targetFileName = fileName + ".disable"
        }

        let targetURL = resourceDir.appendingPathComponent(targetFileName)
        try fileManager.moveItem(at: currentURL, to: targetURL)

        return targetFileName
    }
}
