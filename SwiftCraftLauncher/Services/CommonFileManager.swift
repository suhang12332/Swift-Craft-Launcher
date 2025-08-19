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
            
            // 优先使用LibraryDownloads.artifact
            if let downloads = lib.downloads, let artifactUrl = downloads.artifact.url {
                return JarDownloadTask(
                    name: lib.name,
                    url: artifactUrl,
                    destinationPath: downloads.artifact.path,
                    expectedSha1: downloads.artifact.sha1.isEmpty ? nil : downloads.artifact.sha1
                )
            }
            

            
            return JarDownloadTask(
                name: lib.name,
                url: CommonService.mavenCoordinateToURL(lib: lib),
                destinationPath: CommonService.mavenCoordinateToDefaultPath(lib.name),
                expectedSha1: nil
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
            let result = CommonService.mavenCoordinateToURL(lib: lib)
            return JarDownloadTask(
                name: lib.name,
                url: result,
                destinationPath: CommonService.mavenCoordinateToDefaultPath(lib.name),
                expectedSha1: ""
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
    
    /// 执行processors处理
    /// - Parameters:
    ///   - processors: 处理器列表
    ///   - librariesDir: 库目录
    ///   - gameVersion: 游戏版本
    ///   - data: 数据字段，用于占位符替换
    ///   - onProgressUpdate: 进度更新回调
    /// - Throws: GlobalError 当处理失败时
    func executeProcessors(processors: [Processor], librariesDir: URL, gameVersion: String, data: [String: SidedDataEntry]? = nil, gameName: String? = nil) async throws {
        // 过滤出client端的processor
        let clientProcessors = processors.filter { processor in
            guard let sides = processor.sides else { return true } // 如果没有指定sides，默认执行
            return sides.contains("client")
        }
        
        guard !clientProcessors.isEmpty else { 
            Logger.shared.info("没有找到client端的processor，跳过执行")
            return 
        }
        
        Logger.shared.info("找到 \(clientProcessors.count) 个client端processor，开始执行")
        
        // 使用version.json中的原始data字段，并添加必要的环境变量
        var processorData: [String: String] = [:]
        
        // 添加基础环境变量
        processorData["SIDE"] = "client"
        processorData["MINECRAFT_VERSION"] = gameVersion
        processorData["LIBRARY_DIR"] = librariesDir.path
        
        // 添加Minecraft JAR路径
        if let versionsDir = AppPaths.versionsDirectory {
            let minecraftJarPath = versionsDir.appendingPathComponent(gameVersion).appendingPathComponent("\(gameVersion).jar")
            processorData["MINECRAFT_JAR"] = minecraftJarPath.path
        }
        
        // 添加实例路径（profile目录）
        if let gameName = gameName, let profileDir = AppPaths.profileDirectory(gameName: gameName) {
            processorData["ROOT"] = profileDir.path
        }
        
        // 解析version.json中的data字段
        if let data = data {
            for (key, sidedEntry) in data {
                processorData[key] = CommonFileManager.extractClientValue(from: sidedEntry.client) ?? sidedEntry.client
            }
        }
        
        for processor in clientProcessors {
            do {
                try await executeProcessor(processor, librariesDir: librariesDir, gameVersion: gameVersion, data: processorData)
            } catch {
                Logger.shared.error("执行处理器失败: \(error.localizedDescription)")
                throw GlobalError.download(
                    chineseMessage: "执行处理器失败: \(error.localizedDescription)",
                    i18nKey: "error.download.processor_start_failed",
                    level: .notification
                )
            }
        }
    }
    
    /// 执行单个processor
    /// - Parameters:
    ///   - processor: 处理器
    ///   - librariesDir: 库目录
    ///   - gameVersion: 游戏版本
    ///   - data: 数据字段，用于占位符替换
    /// - Throws: GlobalError 当处理失败时
    private func executeProcessor(_ processor: Processor, librariesDir: URL, gameVersion: String, data: [String: String]? = nil) async throws {
        try await ProcessorExecutor.executeProcessor(
            processor,
            librariesDir: librariesDir,
            gameVersion: gameVersion,
            data: data
        )
    }
    
    /// 从data字段值中提取client端的数据
    /// - Parameter value: data字段的值
    /// - Returns: client端的数据，如果无法解析则返回nil
    static public func extractClientValue(from value: String) -> String? {
        // 如果是Maven坐标格式，直接转换为路径
        if value.contains(":") && !value.hasPrefix("[") && !value.hasPrefix("{") {
            return CommonService.convertMavenCoordinateToPath(value)
        }
        
        // 如果是数组格式，直接提取内容并转换为路径
        if value.hasPrefix("[") && value.hasSuffix("]") {
            let content = String(value.dropFirst().dropLast())
            if content.contains(":") {
                return CommonService.convertMavenCoordinateToPath(content)
            }
            return content
        }
        
        return value
    }
    
    
}
