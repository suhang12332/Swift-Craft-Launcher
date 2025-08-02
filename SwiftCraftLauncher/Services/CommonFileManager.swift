//
//  CommonFileManager.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/7/27.
//
import Foundation

class CommonFileManager {
    let librariesDir: URL
    let session: URLSession
    var onProgressUpdate: ((String, Int, Int) -> Void)?
    private let fileManager = FileManager.default
    private let retryCount = 3
    private let retryDelay: TimeInterval = 2

    init(librariesDir: URL) {
        self.librariesDir = librariesDir
        let config = URLSessionConfiguration.ephemeral
        config.httpMaximumConnectionsPerHost =
            GameSettingsManager.shared.concurrentDownloads
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    actor Counter {
        private var value = 0
        func increment() -> Int {
            value += 1
            return value
        }
    }

    /// 下载 Forge JAR 文件（静默版本）
    /// - Parameter libraries: 要下载的库文件列表
    func downloadForgeJars(libraries: [ModrinthLoaderLibrary]) async {
        do {
            try await downloadForgeJarsThrowing(libraries: libraries)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("下载 Forge JAR 文件失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
        }
    }
    
    /// 下载 Forge JAR 文件（抛出异常版本）
    /// - Parameter libraries: 要下载的库文件列表
    /// - Throws: GlobalError 当下载失败时
    func downloadForgeJarsThrowing(libraries: [ModrinthLoaderLibrary]) async throws {
        let tasks = libraries.compactMap { lib -> JarDownloadTask? in
            guard lib.downloadable else { return nil }
            if lib.downloads != nil {
                let artifact = lib.downloads!.artifact
                return JarDownloadTask(
                    name: lib.name,
                    url: artifact.url!,
                    destinationPath: artifact.path,
                    expectedSha1: artifact.sha1,
                    skip: lib.skip == nil ? false : true
                )
            } else {
                return nil
            }
            
            
        }
        
        guard let metaLibrariesDir = AppPaths.metaDirectory?
            .appendingPathComponent("libraries") else {
            throw GlobalError.configuration(
                chineseMessage: "无法获取元数据目录路径",
                i18nKey: "error.configuration.meta_directory_not_found",
                level: .notification
            )
        }
        
        do {
            try await BatchJarDownloader.download(
                tasks: tasks,
                metaLibrariesDir: metaLibrariesDir,
                onProgressUpdate: self.onProgressUpdate
            )
        } catch {
            let globalError = GlobalError.from(error)
            throw GlobalError.download(
                chineseMessage: "下载 Forge JAR 文件失败: \(globalError.chineseMessage)",
                i18nKey: "error.download.jar_failed",
                level: .notification
            )
        }
    }
    
    /// 下载 FabricJAR 文件（静默版本）
    /// - Parameter libraries: 要下载的库文件列表
    func downloadFabricJars(libraries: [ModrinthLoaderLibrary]) async {
        do {
            try await downloadFabricJarsThrowing(libraries: libraries)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("下载 JAR 文件失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
        }
    }
    
    /// 下载 FabricJAR 文件（抛出异常版本）
    /// - Parameter libraries: 要下载的库文件列表
    /// - Throws: GlobalError 当下载失败时
    func downloadFabricJarsThrowing(libraries: [ModrinthLoaderLibrary]) async throws {
        let tasks = libraries.compactMap { lib -> JarDownloadTask? in
            guard lib.downloadable else { return nil }
            guard let result = CommonService.mavenCoordinateToURL(lib: lib) else { return nil }
            return JarDownloadTask(
                name: lib.name,
                url: result,
                destinationPath: CommonService.mavenURLToMavenPath(url: result),
                expectedSha1: "",
                skip: lib.skip == nil ? false : true
            )
        }
        
        guard let metaLibrariesDir = AppPaths.metaDirectory?
            .appendingPathComponent("libraries") else {
            throw GlobalError.configuration(
                chineseMessage: "无法获取元数据目录路径",
                i18nKey: "error.configuration.meta_directory_not_found",
                level: .notification
            )
        }
        
        do {
            try await BatchJarDownloader.download(
                tasks: tasks,
                metaLibrariesDir: metaLibrariesDir,
                onProgressUpdate: self.onProgressUpdate
            )
        } catch {
            let globalError = GlobalError.from(error)
            throw GlobalError.download(
                chineseMessage: "下载 JAR 文件失败: \(globalError.chineseMessage)",
                i18nKey: "error.download.jar_failed",
                level: .notification
            )
        }
    }
    
    
}
