import Foundation
import SwiftUI

/// 数据源枚举
enum DataSource: String, CaseIterable, Codable {
    case modrinth = "Modrinth"
    case curseforge = "CurseForge"

    var displayName: String {
        switch self {
        case .modrinth:
            return "Modrinth"
        case .curseforge:
            return "CurseForge"
        }
    }

    var localizedName: String {
        "settings.default_api_source.\(rawValue.lowercased())".localized()
    }
}

class GameSettingsManager: ObservableObject {
    // MARK: - 单例实例
    static let shared = GameSettingsManager()

    @AppStorage("globalXms")
    var globalXms: Int = 512 {
        didSet { objectWillChange.send() }
    }

    @AppStorage("globalXmx")
    var globalXmx: Int = 4096 {
        didSet { objectWillChange.send() }
    }

    @AppStorage("enableAICrashAnalysis")
    var enableAICrashAnalysis: Bool = false {
        didSet { objectWillChange.send() }
    }

    @AppStorage("defaultAPISource")
    var defaultAPISource: DataSource = .modrinth {
        didSet { objectWillChange.send() }
    }

    /// 是否在游戏版本选择中包含快照版（全局设置）
    @AppStorage("includeSnapshotsForGameVersions")
    var includeSnapshotsForGameVersions: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// 计算系统最大可用内存分配（基于物理内存的70%）
    var maximumMemoryAllocation: Int {
        let physicalMemoryBytes = ProcessInfo.processInfo.physicalMemory
        let physicalMemoryMB = physicalMemoryBytes / 1_048_576
        let calculatedMax = Int(Double(physicalMemoryMB) * 0.7)
        let roundedMax = (calculatedMax / 512) * 512
        return max(roundedMax, 512)
    }
}
