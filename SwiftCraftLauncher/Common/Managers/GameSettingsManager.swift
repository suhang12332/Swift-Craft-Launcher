import Foundation
import SwiftUI

class GameSettingsManager: ObservableObject {
    // MARK: - 单例实例
    static let shared = GameSettingsManager()

    @AppStorage("autoDownloadDependencies")
    var autoDownloadDependencies: Bool = false {
        didSet { objectWillChange.send() }
    }

    @AppStorage("forgeMavenMirrorURL")
    var forgeMavenMirrorURL: String = "" {
        didSet { objectWillChange.send() }
    }

    @AppStorage("globalXms")
    var globalXms: Int = 512 {
        didSet { objectWillChange.send() }
    }

    @AppStorage("globalXmx")
    var globalXmx: Int = 4096 {
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
