//
//  CommonFileManager.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Manages common file operations for mod loader installations, including
/// Forge and Fabric JAR downloads and processor execution.
class CommonFileManager {
    let librariesDir: URL
    var onProgressUpdate: ((String, Int, Int) -> Void)?
    private let errorHandler: GlobalErrorHandler
    private let javaManager: JavaManager

    init(
        librariesDir: URL,
        errorHandler: GlobalErrorHandler = AppServices.errorHandler,
        javaManager: JavaManager = AppServices.javaManager,
    ) {
        self.librariesDir = librariesDir
        self.errorHandler = errorHandler
        self.javaManager = javaManager
    }

    actor Counter {
        private var value = 0

        func increment() -> Int {
            value += 1
            return value
        }
    }

    /// Downloads Forge JAR files, handling errors silently.
    /// - Parameter libraries: The loader libraries to download.
    func downloadForgeJars(libraries: [ModrinthLoaderLibrary]) async {
        do {
            try await downloadForgeJarsThrowing(libraries: libraries)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error("下载 Forge JAR 文件失败: \(globalError.chineseMessage)")
            errorHandler.handle(globalError)
        }
    }

    /// Downloads Forge JAR files.
    /// - Parameter libraries: The loader libraries to download.
    /// - Throws: A ``GlobalError`` if the download fails.
    func downloadForgeJarsThrowing(libraries: [ModrinthLoaderLibrary]) async throws {
        let tasks = libraries.compactMap { lib -> JarDownloadTask? in
            guard lib.downloadable else { return nil }

            // Prefer LibraryDownloads.artifact
            if let downloads = lib.downloads, let artifactUrl = downloads.artifact.url, let artifactPath = downloads.artifact.path {
                return JarDownloadTask(
                    name: lib.name,
                    url: artifactUrl,
                    destinationPath: artifactPath,
                    expectedSha1: downloads.artifact.sha1.isEmpty ? nil : downloads.artifact.sha1,
                )
            }

            guard let url = CommonService.mavenCoordinateToURL(lib: lib) else { return nil }
            return JarDownloadTask(
                name: lib.name,
                url: url,
                destinationPath: CommonService.mavenCoordinateToDefaultPath(lib.name),
                expectedSha1: nil,
            )
        }

        do {
            try await BatchJarDownloader.download(
                tasks: tasks,
                metaLibrariesDir: AppPaths.librariesDirectory,
                onProgressUpdate: onProgressUpdate,
            )
        } catch {
            let globalError = GlobalError.from(error)
            throw GlobalError.download(
                chineseMessage: "下载 Forge JAR 文件失败: \(globalError.chineseMessage)",
                i18nKey: "error.download.jar_failed",
                level: .notification,
            )
        }
    }

    /// Downloads Fabric JAR files, handling errors silently.
    /// - Parameter libraries: The loader libraries to download.
    func downloadFabricJars(libraries: [ModrinthLoaderLibrary]) async {
        do {
            try await downloadFabricJarsThrowing(libraries: libraries)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error("下载 JAR 文件失败: \(globalError.chineseMessage)")
            errorHandler.handle(globalError)
        }
    }

    /// Downloads Fabric JAR files.
    /// - Parameter libraries: The loader libraries to download.
    /// - Throws: A ``GlobalError`` if the download fails.
    func downloadFabricJarsThrowing(libraries: [ModrinthLoaderLibrary]) async throws {
        let tasks = libraries.compactMap { lib -> JarDownloadTask? in
            guard lib.downloadable else { return nil }
            guard let url = CommonService.mavenCoordinateToURL(lib: lib) else { return nil }
            return JarDownloadTask(
                name: lib.name,
                url: url,
                destinationPath: CommonService.mavenCoordinateToDefaultPath(lib.name),
                expectedSha1: "",
            )
        }

        do {
            try await BatchJarDownloader.download(
                tasks: tasks,
                metaLibrariesDir: AppPaths.librariesDirectory,
                onProgressUpdate: onProgressUpdate,
            )
        } catch {
            let globalError = GlobalError.from(error)
            throw GlobalError.download(
                chineseMessage: "下载 JAR 文件失败: \(globalError.chineseMessage)",
                i18nKey: "error.download.jar_failed",
                level: .notification,
            )
        }
    }

    /// Executes client-side processors defined in the version manifest.
    /// - Parameters:
    ///   - processors: The list of processors to execute.
    ///   - librariesDir: The libraries directory URL.
    ///   - gameVersion: The Minecraft version string.
    ///   - data: Optional data fields for placeholder substitution.
    ///   - gameName: Optional game instance name.
    ///   - onProgressUpdate: Optional progress callback providing the message, current index, and total count.
    /// - Throws: A ``GlobalError`` if any processor fails.
    func executeProcessors(processors: [Processor], librariesDir: URL, gameVersion: String, data: [String: SidedDataEntry]? = nil, gameName: String? = nil, onProgressUpdate: ((String, Int, Int) -> Void)? = nil) async throws {
        // Filter client-side processors
        let clientProcessors = processors.filter { processor in
            guard let sides = processor.sides else { return true }
            return sides.contains(AppConstants.EnvironmentTypes.client)
        }

        guard !clientProcessors.isEmpty else {
            AppLog.game.info("没有找到client端的processor，跳过执行")
            return
        }

        AppLog.game.info("找到 \(clientProcessors.count) 个client端processor，开始执行")

        var processorData: [String: String] = [:]

        // Add base environment variables
        processorData["SIDE"] = AppConstants.EnvironmentTypes.client
        processorData["MINECRAFT_VERSION"] = gameVersion
        processorData["LIBRARY_DIR"] = librariesDir.path

        // Add Minecraft JAR path
        let minecraftJarPath = AppPaths.versionsDirectory.appendingPathComponent(gameVersion).appendingPathComponent("\(gameVersion).jar")
        processorData["MINECRAFT_JAR"] = minecraftJarPath.path

        // Add instance path (profile directory)
        if let gameName {
            processorData["ROOT"] = AppPaths.profileDirectory(gameName: gameName).path
        }

        // Parse data fields from version.json
        if let data {
            for (key, sidedEntry) in data {
                processorData[key] = Self.extractClientValue(from: sidedEntry.client) ?? sidedEntry.client
            }
        }

        let versionInfo = try await ModrinthService.fetchVersionInfo(from: gameVersion)
        let javaPath = javaManager.findJavaExecutable(version: versionInfo.javaVersion.component)

        for (index, processor) in clientProcessors.enumerated() {
            do {
                let processorName = processor.jar ?? "processor.unknown".localized()
                let message = String(format: "processor.executing".localized(), index + 1, clientProcessors.count, processorName)
                onProgressUpdate?(message, index + 1, clientProcessors.count)
                try await executeProcessor(
                    processor,
                    librariesDir: librariesDir,
                    gameVersion: gameVersion,
                    javaPath: javaPath,
                    data: processorData,
                    onProgressUpdate: onProgressUpdate,
                )
            } catch {
                AppLog.game.error("执行处理器失败: \(error.localizedDescription)")
                throw GlobalError.download(
                    chineseMessage: "执行处理器失败: \(error.localizedDescription)",
                    i18nKey: "error.download.processor_start_failed",
                    level: .notification,
                )
            }
        }
    }

    /// Executes a single processor.
    /// - Parameters:
    ///   - processor: The processor to execute.
    ///   - librariesDir: The libraries directory URL.
    ///   - gameVersion: The Minecraft version string.
    ///   - javaPath: The resolved path to the Java executable.
    ///   - data: Optional data fields for placeholder substitution.
    ///   - onProgressUpdate: Optional progress callback.
    /// - Throws: A ``GlobalError`` if the processor fails.
    private func executeProcessor(_ processor: Processor, librariesDir: URL, gameVersion: String, javaPath: String, data: [String: String]? = nil, onProgressUpdate _: ((String, Int, Int) -> Void)? = nil) async throws {
        try await ProcessorExecutor.executeProcessor(
            processor,
            librariesDir: librariesDir,
            gameVersion: gameVersion,
            javaPath: javaPath,
            data: data,
        )
    }

    /// Extracts client-side data from a sided data field value.
    /// - Parameter value: The data field value to parse.
    /// - Returns: The extracted client data, or `nil` if parsing fails.
    static func extractClientValue(from value: String) -> String? {
        // Convert Maven coordinate format to path
        if value.contains(":"), !value.hasPrefix("["), !value.hasPrefix("{") {
            return CommonService.convertMavenCoordinateToPath(value)
        }

        // Extract content from array format and convert to path
        if value.hasPrefix("["), value.hasSuffix("]") {
            let content = String(value.dropFirst().dropLast())
            if content.contains(":") {
                return CommonService.convertMavenCoordinateToPath(content)
            }
            return content
        }
        return value
    }
}
