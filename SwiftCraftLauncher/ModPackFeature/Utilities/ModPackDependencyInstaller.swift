//
//  ModPackDependencyInstaller.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/8/3.
//

import Foundation

/// 整合包依赖安装服务
/// 负责安装整合包中定义的所有必需依赖
enum ModPackDependencyInstaller {
    static var downloadSemaphoreValue: Int {
        max(1, AppServices.generalSettingsManager.concurrentDownloads / 4)
    }

    enum DownloadType {
        case files
        case dependencies
        case overrides
    }

    /// 安装整合包版本的所有必需依赖
    static func installVersionDependencies(
        indexInfo: ModrinthIndexInfo,
        gameInfo: GameVersionInfo,
        extractedPath: URL? = nil,
        onProgressUpdate: ((String, Int, Int, DownloadType) -> Void)? = nil
    ) async -> Bool {
        let resourceDir = AppPaths.profileDirectory(gameName: gameInfo.gameName)

        async let filesResult = installModPackFiles(
            files: indexInfo.files,
            resourceDir: resourceDir,
            gameInfo: gameInfo,
            onProgressUpdate: onProgressUpdate
        )

        async let dependenciesResult = installModPackDependencies(
            dependencies: indexInfo.dependencies,
            gameInfo: gameInfo,
            resourceDir: resourceDir,
            onProgressUpdate: onProgressUpdate
        )

        let (filesSuccess, dependenciesSuccess) = await (filesResult, dependenciesResult)

        if !filesSuccess {
            Logger.shared.error("整合包文件安装失败")
            return false
        }

        if !dependenciesSuccess {
            Logger.shared.error("整合包依赖安装失败")
            return false
        }

        return true
    }
}

// MARK: - Thread-safe Counter
final class ModPackCounter {
    private var count = 0
    private let lock = NSLock()

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        count = 0
    }
}
