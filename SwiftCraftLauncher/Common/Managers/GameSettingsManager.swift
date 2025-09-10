import Foundation
import SwiftUI

class GameSettingsManager: ObservableObject {
    // MARK: - 单例实例
    static let shared = GameSettingsManager()

    // MARK: - 应用设置属性
    @AppStorage("concurrentDownloads")
    var concurrentDownloads: Int = 64 {
        didSet {
            if concurrentDownloads < 1 {
                concurrentDownloads = 1
            }
            objectWillChange.send()
        }
    }

    @AppStorage("autoDownloadDependencies")
    var autoDownloadDependencies: Bool = false {
        didSet { objectWillChange.send() }
    }

    @AppStorage("minecraftVersionManifestURL")
    var minecraftVersionManifestURL: String = "https://launchermeta.mojang.com/mc/game/version_manifest.json" {
        didSet { objectWillChange.send() }
    }

    @AppStorage("modrinthAPIBaseURL")
    var modrinthAPIBaseURL: String = "https://api.modrinth.com/v2" {
        didSet { objectWillChange.send() }
    }

    @AppStorage("forgeMavenMirrorURL")
    var forgeMavenMirrorURL: String = "" {
        didSet { objectWillChange.send() }
    }

    @AppStorage("gitProxyURL")
    var gitProxyURL: String = "https://ghfast.top" {
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
