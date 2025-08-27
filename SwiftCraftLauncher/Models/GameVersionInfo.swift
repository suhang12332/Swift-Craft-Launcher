//
//  GameModels.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/5/30.
//

import Foundation
import SwiftUI



/// 游戏版本信息模型
/// 用于存储和管理游戏版本的相关信息，包括启动配置等
struct GameVersionInfo: Codable, Identifiable, Hashable {
    /// 游戏版本唯一标识符
    let id: String
    
    /// 游戏名称
    let gameName: String
    
    /// 游戏图标路径或URL
    let gameIcon: String
    
    /// 游戏版本号
    let gameVersion: String
    
    /// Mod版本号
    var modVersion: String
    
    /// Mod JVM参数
    var modJvm: [String] = []
    
    var modClassPath: String
    
    /// 资源索引版本
    var assetIndex: String
    
    /// 模组加载器类型（如 Forge、Fabric 等）
    let modLoader: String
    
    /// 是否为用户手动添加的版本
    /// - true: 用户手动添加
    /// - false: 下载的整合包
    let isUserAdded: Bool
    
    /// 创建时间
    let createdAt: Date
    
    /// 最后游玩时间
    var lastPlayed: Date
    
    /// 游戏是否正在运行
    var isRunning: Bool
    
    /// Java 运行环境路径
    var javaPath: String
    
    /// 自定义 JVM 启动参数
    var jvmArguments: String
    
    /// 游戏启动命令
    var launchCommand: [String]
    
    /// 运行内存大小 (MB)
    var xms: Int
    var xmx: Int
    
    var javaVersion: Int
    /// 游戏主类（Main Class）
    var mainClass: String

    /// 启动参数（如 --launchTarget forge_client 等）
    var gameArguments: [String] = []
    
    /// 环境变量设置
    var environmentVariables: String

    /// 初始化游戏版本信息
    /// - Parameters:
    ///   - id: 游戏版本ID，默认生成新的UUID
    ///   - gameName: 游戏名称
    ///   - gameIcon: 游戏图标路径
    ///   - gameVersion: 游戏版本号
    ///   - modVersion: Mod版本号
    ///   - modJvm: Mod JVM参数，默认空字符串
    ///   - modClassPath: Mod Classpath参数，默认空字符串
    ///   - assetIndex: 资源索引版本
    ///   - modLoader: 模组加载器类型
    ///   - isUserAdded: 是否用户手动添加
    ///   - createdAt: 创建时间，默认当前时间
    ///   - lastPlayed: 最后游玩时间，默认当前时间
    ///   - isRunning: 是否正在运行，默认false
    ///   - javaPath: Java路径，默认空字符串
    ///   - jvmArguments: JVM参数，默认空字符串
    ///   - launchCommand: 启动命令，默认空字符串
    ///   - runningMemorySize: 运行内存大小 (MB)，默认 2048
    ///   - resources: 游戏资源列表，默认空数组
    ///   - mainClass: 游戏主类，默认空字符串
    ///   - gameArguments: 启动参数，默认空数组
    ///   - environmentVariables: 环境变量，默认空字符串
    init(
        id: UUID = UUID(),
        gameName: String,
        gameIcon: String,
        gameVersion: String,
        modVersion: String = "",
        modJvm: [String] = [],
        modClassPath: String = "",
        assetIndex: String,
        modLoader: String,
        isUserAdded: Bool,
        createdAt: Date = Date(),
        lastPlayed: Date = Date(),
        isRunning: Bool = false,
        javaPath: String = "",
        jvmArguments: String = "",
        launchCommand: [String] = [],
        xms: Int = 0,
        xmx: Int = 0,
        javaVersion: Int = 8,
        mainClass: String = "",
        gameArguments: [String] = [],
        environmentVariables: String = ""
    ) {
        self.id = id.uuidString
        self.gameName = gameName
        self.gameIcon = gameIcon
        self.gameVersion = gameVersion
        self.modVersion = modVersion
        self.modJvm = modJvm
        self.modClassPath = modClassPath
        self.assetIndex = assetIndex
        self.modLoader = modLoader
        self.isUserAdded = isUserAdded
        self.createdAt = createdAt
        self.lastPlayed = lastPlayed
        self.isRunning = isRunning
        self.javaPath = javaPath
        self.jvmArguments = jvmArguments
        self.launchCommand = launchCommand
        self.xms = xms
        self.xmx = xmx
        self.mainClass = mainClass
        self.gameArguments = gameArguments
        self.javaVersion = javaVersion
        self.environmentVariables = environmentVariables
    }
    
    /// 获取所有检测到的Java路径，key为版本号，value为路径
    static var detectedJavaPaths: [String: String] {
        GameSettingsManager.shared.allJavaPaths
    }
    
    /// 按Java主版本号匹配的Java路径
    var detectedJavaPath: String? {
        GameSettingsManager.shared.allJavaPaths.first(where: { (key, _) in
            if let intVer = Int(key.split(separator: ".").first ?? "") {
                return intVer == self.javaVersion
            }
            return false
        })?.value
    }
}
