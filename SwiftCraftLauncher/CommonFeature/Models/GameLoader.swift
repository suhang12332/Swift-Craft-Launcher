import Foundation

/// Minecraft 游戏加载器（Mod Loader）
enum GameLoader: String, CaseIterable, Identifiable, Codable, Sendable {
    /// 原版（Vanilla）
    case vanilla
    case fabric
    case forge
    case neoforge
    case quilt

    var id: String { rawValue }

    /// UI 显示用名称（包含“原版”）
    var displayName: String {
        switch self {
        case .vanilla: "vanilla"
        case .fabric: "fabric"
        case .forge: "forge"
        case .neoforge: "neoforge"
        case .quilt: "quilt"
        }
    }
}
