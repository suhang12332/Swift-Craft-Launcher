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

            guard let url = CommonService.mavenCoordinateToURL(lib: lib) else { return nil }
            return JarDownloadTask(
                name: lib.name,
                url: url,
                destinationPath: CommonService.mavenCoordinateToDefaultPath(lib.name),
                expectedSha1: nil
            )
        }

        do {
            try await BatchJarDownloader.download(
                tasks: tasks,
                metaLibrariesDir: AppPaths.librariesDirectory,
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
            guard let url = CommonService.mavenCoordinateToURL(lib: lib) else { return nil }
            return JarDownloadTask(
                name: lib.name,
                url: url,
                destinationPath: CommonService.mavenCoordinateToDefaultPath(lib.name),
                expectedSha1: ""
            )
        }

        do {
            try await BatchJarDownloader.download(
                tasks: tasks,
                metaLibrariesDir: AppPaths.librariesDirectory,
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
    ///   - gameName: 游戏名称（可选）
    ///   - onProgressUpdate: 进度更新回调（可选，包含当前处理器索引和总处理器数量）
    /// - Throws: GlobalError 当处理失败时
    func executeProcessors(processors: [Processor], librariesDir: URL, gameVersion: String, data: [String: SidedDataEntry]? = nil, gameName: String? = nil, onProgressUpdate: ((String, Int, Int) -> Void)? = nil) async throws {
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
        let minecraftJarPath = AppPaths.versionsDirectory.appendingPathComponent(gameVersion).appendingPathComponent("\(gameVersion).jar")
        processorData["MINECRAFT_JAR"] = minecraftJarPath.path

        // 添加实例路径（profile目录）
        if let gameName = gameName {
            processorData["ROOT"] = AppPaths.profileDirectory(gameName: gameName).path
        }

        // 解析version.json中的data字段
        if let data = data {
            for (key, sidedEntry) in data {
                processorData[key] = Self.extractClientValue(from: sidedEntry.client) ?? sidedEntry.client
            }
        }

        for (index, processor) in clientProcessors.enumerated() {
            do {
                let processorName = processor.jar ?? "processor.unknown".localized()
                let message = String(format: "processor.executing".localized(), index + 1, clientProcessors.count, processorName)
                onProgressUpdate?(message, index + 1, clientProcessors.count)
                try await executeProcessor(processor, librariesDir: librariesDir, gameVersion: gameVersion, data: processorData, onProgressUpdate: onProgressUpdate)
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
    ///   - onProgressUpdate: 进度更新回调（可选，包含当前处理器索引和总处理器数量）
    /// - Throws: GlobalError 当处理失败时
    private func executeProcessor(_ processor: Processor, librariesDir: URL, gameVersion: String, data: [String: String]? = nil, onProgressUpdate: ((String, Int, Int) -> Void)? = nil) async throws {
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
    static func extractClientValue(from value: String) -> String? {
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
