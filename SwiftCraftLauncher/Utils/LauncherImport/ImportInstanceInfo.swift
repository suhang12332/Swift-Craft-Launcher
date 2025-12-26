//
//  ImportInstanceInfo.swift
//  SwiftCraftLauncher
//
//

import Foundation

/// 导入实例信息
/// 包含从其他启动器解析出的所有必要信息
struct ImportInstanceInfo {
    /// 游戏名称
    let gameName: String

    /// 游戏版本
    let gameVersion: String

    /// Mod加载器类型（vanilla, fabric, forge, neoforge, quilt）
    let modLoader: String

    /// Mod加载器版本
    let modLoaderVersion: String

    /// 游戏图标路径（如果有）
    let gameIconPath: URL?

    /// 图标下载 URL（如果需要从网络下载）
    let iconDownloadUrl: String?

    /// 源游戏目录路径（.minecraft 文件夹所在位置）
    let sourceGameDirectory: URL

    /// 实例文件夹路径（用于获取其他信息）
    let instanceFolder: URL

    /// 启动器类型
    let launcherType: ImportLauncherType
}
