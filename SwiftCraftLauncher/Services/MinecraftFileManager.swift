import CommonCrypto
import Foundation

// MARK: - Constants
private enum Constants {
    static let metaSubdirectories = [
        "versions",
        "libraries",
        "assets",
        "assets/indexes",
        "assets/objects",
    ]
    static let assetChunkSize = 500
    static let downloadTimeout: TimeInterval = 30
    static let retryCount = 3
    static let retryDelay: TimeInterval = 2
    static let memoryBufferSize = 1024 * 1024  // 1MB buffer for file operations
}

// MARK: - MinecraftFileManager
class MinecraftFileManager {  // swiftlint:disable:this type_body_length

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let session: URLSession
    private let coreFilesCount = NSLockingCounter()
    private let resourceFilesCount = NSLockingCounter()
    private var coreTotalFiles = 0
    private var resourceTotalFiles = 0
    private let downloadQueue = DispatchQueue(
        label: "com.launcher.download",
        qos: .userInitiated
    )

    var onProgressUpdate: ((String, Int, Int, DownloadType) -> Void)?

    enum DownloadType {
        case core
        case resources
    }

    // MARK: - Initialization
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = Constants.downloadTimeout
        config.timeoutIntervalForResource = Constants.downloadTimeout
        config.httpMaximumConnectionsPerHost =
            GameSettingsManager.shared.concurrentDownloads
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public Methods

    /// 下载版本文件（静默版本）
    /// - Parameters:
    ///   - manifest: Minecraft 版本清单
    ///   - gameName: 游戏名称
    /// - Returns: 是否成功下载
    func downloadVersionFiles(
        manifest: MinecraftVersionManifest,
        gameName: String
    ) async -> Bool {
        do {
            try await downloadVersionFilesThrowing(
                manifest: manifest,
                gameName: gameName
            )
            return true
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error(
                "下载 Minecraft 版本文件失败: \(globalError.chineseMessage)"
            )
            GlobalErrorHandler.shared.handle(globalError)
            return false
        }
    }

    /// 下载版本文件（抛出异常版本）
    /// - Parameters:
    ///   - manifest: Minecraft 版本清单
    ///   - gameName: 游戏名称
    /// - Throws: GlobalError 当操作失败时
    func downloadVersionFilesThrowing(
        manifest: MinecraftVersionManifest,
        gameName: String
    ) async throws {
        Logger.shared.info(
            String(
                format: "log.minecraft.download.start".localized(),
                manifest.id
            )
        )

        try createDirectories(manifestId: manifest.id, gameName: gameName)

        // Use bounded task groups to limit concurrency
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                try await self?.downloadCoreFiles(manifest: manifest)
            }
            group.addTask { [weak self] in
                try await self?.downloadAssets(manifest: manifest)
            }

            try await group.waitForAll()
        }

        Logger.shared.info(
            String(
                format: "log.minecraft.download.complete".localized(),
                manifest.id
            )
        )
    }

    // MARK: - Private Methods
    private func calculateTotalFiles(_ manifest: MinecraftVersionManifest) -> Int {
        1 + manifest.libraries.count + 1 + 1  // Client JAR + Libraries + Asset index + Logging config
    }

    private func createDirectories(
        manifestId: String,
        gameName: String
    ) throws {
        guard
            let profileDirectory = AppPaths.profileDirectory(gameName: gameName)
        else {
            throw GlobalError.configuration(
                chineseMessage: "无法获取必要的目录路径",
                i18nKey: "error.configuration.required_directories_not_found",
                level: .notification
            )
        }
        let directoriesToCreate =
            Constants.metaSubdirectories.map {
                AppPaths.metaDirectory.appendingPathComponent($0)
            } + [
                AppPaths.metaDirectory.appendingPathComponent("versions")
                    .appendingPathComponent(manifestId),
                profileDirectory,
            ]
        let profileSubfolders = AppPaths.profileSubdirectories.map {
            profileDirectory.appendingPathComponent($0)
        }
        let allDirectories = directoriesToCreate + profileSubfolders

        for directory in allDirectories {
            if !fileManager.fileExists(atPath: directory.path) {
                do {
                    try fileManager.createDirectory(
                        at: directory,
                        withIntermediateDirectories: true
                    )
                    Logger.shared.debug("创建目录：\(directory.path)")
                } catch {
                    throw GlobalError.fileSystem(
                        chineseMessage:
                            "创建目录失败: \(directory.path), 错误: \(error.localizedDescription)",
                        i18nKey: "error.filesystem.directory_creation_failed",
                        level: .notification
                    )
                }
            }
        }
    }

    private func downloadCoreFiles(manifest: MinecraftVersionManifest) async throws {
        coreTotalFiles = calculateTotalFiles(manifest)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                try await self?.downloadClientJar(manifest: manifest)
            }
            group.addTask { [weak self] in
                try await self?.downloadLibraries(manifest: manifest)
            }
            group.addTask { [weak self] in
                try await self?.downloadLoggingConfig(manifest: manifest)
            }

            try await group.waitForAll()
        }
    }

    private func downloadClientJar(
        manifest: MinecraftVersionManifest
    ) async throws {
        let versionDir = AppPaths.versionsDirectory.appendingPathComponent(
            manifest.id
        )
        let destinationURL = versionDir.appendingPathComponent(
            "\(manifest.id).jar"
        )

        do {
            _ = try await DownloadManager.downloadFile(
                urlString: manifest.downloads.client.url.absoluteString,
                destinationURL: destinationURL,
                expectedSha1: manifest.downloads.client.sha1
            )
            incrementCompletedFilesCount(
                fileName: "file.client.jar".localized(),
                type: .core
            )
        } catch {
            let globalError = GlobalError.from(error)
            throw GlobalError.download(
                chineseMessage: "下载客户端 JAR 文件失败: \(globalError.chineseMessage)",
                i18nKey: "error.download.client_jar_failed",
                level: .notification
            )
        }
    }

    private func downloadLibraries(
        manifest: MinecraftVersionManifest
    ) async throws {

        Logger.shared.info("开始下载库文件")
        let osxLibraries = manifest.libraries.filter {
            isLibraryAllowedOnOSX($0.rules)
        }

        // 创建信号量控制并发数量
        let semaphore = AsyncSemaphore(
            value: GameSettingsManager.shared.concurrentDownloads
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for library in osxLibraries {
                group.addTask { [weak self] in
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }

                    try await self?.downloadLibrary(
                        library,
                        metaDirectory: AppPaths.metaDirectory
                    )
                }
            }
            try await group.waitForAll()
        }
        Logger.shared.info("完成下载库文件")
    }

    private func downloadLibrary(
        _ library: Library,
        metaDirectory: URL
    ) async throws {
        let destinationURL = metaDirectory.appendingPathComponent("libraries")
            .appendingPathComponent(library.downloads.artifact.path)

        do {
            _ = try await DownloadManager.downloadFile(
                urlString: library.downloads.artifact.url!.absoluteString,
                destinationURL: destinationURL,
                expectedSha1: library.downloads.artifact.sha1
            )
            incrementCompletedFilesCount(
                fileName: String(
                    format: "file.library".localized(),
                    library.name
                ),
                type: .core
            )
            if let classifiers = library.downloads.classifiers {
                try await downloadNativeLibrary(
                    library: library,
                    classifiers: classifiers,
                    metaDirectory: metaDirectory
                )
            }
        } catch {
            let globalError = GlobalError.from(error)
            throw GlobalError.download(
                chineseMessage:
                    "下载库文件失败 \(library.name): \(globalError.chineseMessage)",
                i18nKey: "error.download.library_failed",
                level: .notification
            )
        }
    }

    private func downloadNativeLibrary(
        library: Library,
        classifiers: [String: LibraryArtifact],
        metaDirectory: URL
    ) async throws {
        #if os(macOS)
            let osClassifier = library.natives?["osx"]
        #elseif os(Linux)
            let osClassifier = library.natives?["linux"]
        #elseif os(Windows)
            let osClassifier = library.natives?["windows"]
        #else
            let osClassifier = nil
        #endif

        if let classifierKey = osClassifier, let nativeArtifact = classifiers[classifierKey] {
            let destinationURL = metaDirectory.appendingPathComponent("natives")
                .appendingPathComponent(nativeArtifact.path)

            do {
                _ = try await DownloadManager.downloadFile(
                    urlString: nativeArtifact.url!.absoluteString,
                    destinationURL: destinationURL,
                    expectedSha1: nativeArtifact.sha1
                )
                incrementCompletedFilesCount(
                    fileName: String(
                        format: "file.native".localized(),
                        library.name
                    ),
                    type: .core
                )
            } catch {
                let globalError = GlobalError.from(error)
                throw GlobalError.download(
                    chineseMessage:
                        "下载原生库文件失败 \(library.name): \(globalError.chineseMessage)",
                    i18nKey: "error.download.native_library_failed",
                    level: .notification
                )
            }
        }
    }

    private func downloadAssets(
        manifest: MinecraftVersionManifest
    ) async throws {
        Logger.shared.info(
            String(
                format: "log.minecraft.download.assets.start".localized(),
                manifest.id
            )
        )

        let assetIndex = try await downloadAssetIndex(manifest: manifest)
        resourceTotalFiles = assetIndex.objects.count

        try await downloadAllAssets(assetIndex: assetIndex)

        Logger.shared.info(
            String(
                format: "log.minecraft.download.assets.complete".localized(),
                manifest.id
            )
        )
    }

    private func downloadAssetIndex(
        manifest: MinecraftVersionManifest
    ) async throws -> DownloadedAssetIndex {

        let destinationURL = AppPaths.metaDirectory.appendingPathComponent(
            "assets/indexes"
        )
        .appendingPathComponent("\(manifest.assetIndex.id).json")

        do {
            _ = try await DownloadManager.downloadFile(
                urlString: manifest.assetIndex.url.absoluteString,
                destinationURL: destinationURL,
                expectedSha1: manifest.assetIndex.sha1
            )
            let data = try Data(contentsOf: destinationURL)
            let assetIndexData = try JSONDecoder().decode(
                AssetIndexData.self,
                from: data
            )
            var totalSize = 0
            for object in assetIndexData.objects.values {
                totalSize += object.size
            }
            return DownloadedAssetIndex(
                id: manifest.assetIndex.id,
                url: manifest.assetIndex.url,
                sha1: manifest.assetIndex.sha1,
                totalSize: totalSize,
                objects: assetIndexData.objects
            )
        } catch {
            let globalError = GlobalError.from(error)
            throw GlobalError.download(
                chineseMessage: "下载资源索引失败: \(globalError.chineseMessage)",
                i18nKey: "error.download.asset_index_failed",
                level: .notification
            )
        }
    }

    private func downloadLoggingConfig(
        manifest: MinecraftVersionManifest
    ) async throws {
        let loggingFile = manifest.logging.client.file
        let versionDir = AppPaths.metaDirectory.appendingPathComponent(
            "versions"
        )
        .appendingPathComponent(manifest.id)

        let destinationURL = versionDir.appendingPathComponent(loggingFile.id)

        do {
            _ = try await DownloadManager.downloadFile(
                urlString: loggingFile.url.absoluteString,
                destinationURL: destinationURL,
                expectedSha1: loggingFile.sha1
            )
            incrementCompletedFilesCount(
                fileName: "file.logging.config".localized(),
                type: .core
            )
        } catch {
            let globalError = GlobalError.from(error)
            throw GlobalError.download(
                chineseMessage: "下载日志配置文件失败: \(globalError.chineseMessage)",
                i18nKey: "error.download.logging_config_failed",
                level: .notification
            )
        }
    }

    private func downloadAndSaveFile(
        from url: URL,
        to destinationURL: URL,
        sha1: String?,
        fileNameForNotification: String? = nil,
        type: DownloadType
    ) async throws {
        // Create parent directory if needed
        do {
            try fileManager.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage:
                    "创建目录失败: \(destinationURL.deletingLastPathComponent().path), 错误: \(error.localizedDescription)",
                i18nKey: "error.filesystem.directory_creation_failed",
                level: .notification
            )
        }

        // Download without retry
        do {
            let (tempFileURL, response) = try await session.download(from: url)
            defer { try? fileManager.removeItem(at: tempFileURL) }

            guard let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200
            else {
                throw GlobalError.download(
                    chineseMessage: "HTTP 响应错误: \(response)",
                    i18nKey: "error.download.http_response_error",
                    level: .notification
                )
            }

            // Verify SHA1 if needed
            if let expectedSha1 = sha1 {
                let downloadedSha1 = try await calculateFileSHA1(
                    at: tempFileURL
                )
                if downloadedSha1 != expectedSha1 {
                    throw GlobalError.download(
                        chineseMessage:
                            "SHA1 校验失败: 期望 \(expectedSha1), 实际 \(downloadedSha1)",
                        i18nKey: "error.download.sha1_verification_failed",
                        level: .notification
                    )
                }
            }

            // Move file to final location atomically
            do {
                try fileManager.moveItem(at: tempFileURL, to: destinationURL)
            } catch {
                throw GlobalError.fileSystem(
                    chineseMessage: "移动文件失败: \(error.localizedDescription)",
                    i18nKey: "error.filesystem.file_move_failed",
                    level: .notification
                )
            }

            incrementCompletedFilesCount(
                fileName: fileNameForNotification
                    ?? destinationURL.lastPathComponent,
                type: type
            )
        } catch {
            let globalError = GlobalError.from(error)
            throw GlobalError.download(
                chineseMessage: "下载文件失败: \(globalError.chineseMessage)",
                i18nKey: "error.download.file_download_failed",
                level: .notification
            )
        }
    }

    private func verifyExistingFile(
        at url: URL,
        expectedSha1: String
    ) async throws -> Bool {
        let fileSha1 = try await calculateFileSHA1(at: url)
        return fileSha1 == expectedSha1
    }

    private func calculateFileSHA1(at url: URL) async throws -> String {
        return try SHA1Calculator.sha1(ofFileAt: url)
    }

    private func incrementCompletedFilesCount(
        fileName: String,
        type: DownloadType
    ) {
        let currentCount: Int
        let total: Int

        switch type {
        case .core:
            currentCount = coreFilesCount.increment()
            total = coreTotalFiles
        case .resources:
            currentCount = resourceFilesCount.increment()
            total = resourceTotalFiles
        }

        onProgressUpdate?(fileName, currentCount, total, type)
    }

    private func downloadAllAssets(
        assetIndex: DownloadedAssetIndex
    ) async throws {

        let objectsDirectory = AppPaths.metaDirectory.appendingPathComponent(
            "assets/objects"
        )
        let assets = Array(assetIndex.objects)

        // 创建信号量控制并发数量
        let semaphore = AsyncSemaphore(
            value: GameSettingsManager.shared.concurrentDownloads
        )

        // Process assets in chunks to balance memory usage and performance
        for chunk in stride(
            from: 0,
            to: assets.count,
            by: Constants.assetChunkSize
        ) {
            let end = min(chunk + Constants.assetChunkSize, assets.count)
            let currentChunk = assets[chunk..<end]

            try await withThrowingTaskGroup(of: Void.self) { group in
                for (path, asset) in currentChunk {
                    group.addTask { [weak self] in
                        await semaphore.wait()
                        defer { Task { await semaphore.signal() } }

                        try await self?.downloadAsset(
                            asset: asset,
                            path: path,
                            objectsDirectory: objectsDirectory
                        )
                    }
                }
                try await group.waitForAll()
            }
        }
    }

    private func downloadAsset(
        asset: AssetIndexData.AssetObject,
        path: String,
        objectsDirectory: URL
    ) async throws {
        let hashPrefix = String(asset.hash.prefix(2))
        let assetDirectory = objectsDirectory.appendingPathComponent(hashPrefix)
        let destinationURL = assetDirectory.appendingPathComponent(asset.hash)

        do {
            _ = try await DownloadManager.downloadFile(
                urlString:
                    "https://resources.download.minecraft.net/\(String(asset.hash.prefix(2)))/\(asset.hash)",
                destinationURL: destinationURL,
                expectedSha1: asset.hash
            )
            incrementCompletedFilesCount(
                fileName: String(format: "file.asset".localized(), path),
                type: .resources
            )
        } catch {
            let globalError = GlobalError.from(error)
            throw GlobalError.download(
                chineseMessage:
                    "下载资源文件失败 \(path): \(globalError.chineseMessage)",
                i18nKey: "error.download.asset_file_failed",
                level: .notification
            )
        }
    }
}

// MARK: - Asset Index Data Types
// 移除了 DownloadedAssetIndex 和 AssetIndexData 的定义，直接引用 Models/MinecraftManifest.swift 中的类型。

// MARK: - Thread-safe Counter
final class NSLockingCounter {
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

// MARK: - Library 扩展（如有需要）
extension Library {
    var artifactPath: String? {
        downloads.artifact.path
    }
    var artifactURL: URL? {
        downloads.artifact.url
    }
    var artifactSHA1: String? {
        downloads.artifact.sha1
    }
    // 其他业务相关扩展
}

extension MinecraftFileManager {
    /// 判断库是否允许在 macOS (osx) 下加载
    func isLibraryAllowedOnOSX(_ rules: [Rule]?) -> Bool {
        guard let rules = rules else { return true }  // 没有规则默认允许
        var allowed: Bool?
        for rule in rules {
            let osMatch = rule.os?.name == nil || rule.os?.name == "osx"
            if osMatch {
                if rule.action == "allow" {
                    allowed = true
                } else if rule.action == "disallow" {
                    allowed = false
                }
            }
        }
        return allowed ?? true
    }
}

// 移除了 DownloadedAssetIndex 和 AssetIndexData 的定义，直接引用 Models/MinecraftManifest.swift 中的类型。
