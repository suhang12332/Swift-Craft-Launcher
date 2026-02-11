import Foundation

/// 统一的架构辅助工具，集中处理编译期架构分支
enum Architecture {
    case arm64
    case x86_64

    /// 当前编译架构
    static let current: Architecture = {
        #if arch(arm64)
        return .arm64
        #else
        return .x86_64
        #endif
    }()

    /// Java 相关架构字符串
    var javaArch: String {
        switch self {
        case .arm64: return "aarch64"
        case .x86_64: return "x86_64"
        }
    }

    /// Sparkle / 通用架构字符串
    var sparkleArch: String {
        switch self {
        case .arm64: return "arm64"
        case .x86_64: return "x86_64"
        }
    }

    /// 用于 Java Runtime API 的平台标识
    var macPlatformId: String {
        switch self {
        case .arm64: return "mac-os-arm64"
        case .x86_64: return "mac-os"
        }
    }

    /// 当前架构对应的 macOS 标识符列表（按优先级）
    /// - Parameter isLowVersion: 是否为低版本（Minecraft < 1.19）
    func macOSIdentifiers(isLowVersion: Bool) -> [String] {
        switch self {
        case .arm64:
            if isLowVersion {
                return ["osx-arm64", "macos-arm64"]
            } else {
                return ["osx-arm64", "macos-arm64", "osx", "macos"]
            }
        case .x86_64:
            return ["osx", "macos"]
        }
    }
}
