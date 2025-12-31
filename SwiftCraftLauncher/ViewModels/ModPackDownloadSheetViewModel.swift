import CommonCrypto
//
//  ModPackDownloadSheetViewModel.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/8/3.
//
import Foundation
import SwiftUI
import ZIPFoundation
// MARK: - View Model
@MainActor
class ModPackDownloadSheetViewModel: ObservableObject {
    @Published var projectDetail: ModrinthProjectDetail?
    @Published var availableGameVersions: [String] = []
    @Published var filteredModPackVersions: [ModrinthProjectDetailVersion] = []
    @Published var isLoadingModPackVersions = false
    @Published var isLoadingProjectDetails = true
    @Published var lastParsedIndexInfo: ModrinthIndexInfo?

    // 整合包安装进度状态
    @Published var modPackInstallState = ModPackInstallState()

    // 整合包文件下载进度状态
    @Published var modPackDownloadProgress: Int64 = 0  // 已下载字节数
    @Published var modPackTotalSize: Int64 = 0  // 总文件大小
    // MARK: - Memory Management
    /// 清理不再需要的索引数据以释放内存
    /// 在 ModPack 安装完成后调用
    func clearParsedIndexInfo() {
        lastParsedIndexInfo = nil
    }

    /// 清理所有整合包导入相关的数据和临时文件
    func cleanupAllData() {
        // 清理索引数据
        clearParsedIndexInfo()

        // 清理项目详情数据
        projectDetail = nil
        availableGameVersions = []
        filteredModPackVersions = []
        allModPackVersions = []

        // 清理安装状态
        modPackInstallState.reset()

        // 清理下载进度
        modPackDownloadProgress = 0
        modPackTotalSize = 0

        // 清理临时文件
        cleanupTempFiles()
    }

    /// 清理临时文件（modpack_download 和 modpack_extraction 目录）
    func cleanupTempFiles() {
        let tempBaseDir = FileManager.default.temporaryDirectory

        // 清理 modpack_download 目录
        let downloadDir = tempBaseDir.appendingPathComponent("modpack_download")
        if FileManager.default.fileExists(atPath: downloadDir.path) {
            do {
                try FileManager.default.removeItem(at: downloadDir)
                Logger.shared.info("已清理临时下载目录: \(downloadDir.path)")
            } catch {
                Logger.shared.warning("清理临时下载目录失败: \(error.localizedDescription)")
            }
        }

        // 清理 modpack_extraction 目录
        let extractionDir = tempBaseDir.appendingPathComponent("modpack_extraction")
        if FileManager.default.fileExists(atPath: extractionDir.path) {
            do {
                try FileManager.default.removeItem(at: extractionDir)
                Logger.shared.info("已清理临时解压目录: \(extractionDir.path)")
            } catch {
                Logger.shared.warning("清理临时解压目录失败: \(error.localizedDescription)")
            }
        }
    }

    private var allModPackVersions: [ModrinthProjectDetailVersion] = []
    private var gameRepository: GameRepository?

    func setGameRepository(_ repository: GameRepository) {
        self.gameRepository = repository
    }

    /// 应用预加载的项目详情，避免在 sheet 内重复加载
    func applyPreloadedDetail(_ detail: ModrinthProjectDetail) {
        projectDetail = detail
        availableGameVersions = CommonUtil.sortMinecraftVersions(detail.gameVersions)
        isLoadingProjectDetails = false
    }

    // MARK: - Data Loading
    func loadProjectDetails(projectId: String) async {
        isLoadingProjectDetails = true

        do {
            projectDetail =
                try await ModrinthService.fetchProjectDetailsThrowing(
                    id: projectId
                )
            let gameVersions = projectDetail?.gameVersions ?? []
            availableGameVersions = CommonUtil.sortMinecraftVersions(gameVersions)
        } catch {
            let globalError = GlobalError.from(error)
            GlobalErrorHandler.shared.handle(globalError)
        }

        isLoadingProjectDetails = false
    }

    func loadModPackVersions(for gameVersion: String) async {
        guard let projectDetail = projectDetail else { return }

        isLoadingModPackVersions = true

        do {
            allModPackVersions =
                try await ModrinthService.fetchProjectVersionsThrowing(
                    id: projectDetail.id
                )
            filteredModPackVersions = allModPackVersions
                .filter { version in
                    version.gameVersions.contains(gameVersion)
                }
                .sorted { version1, version2 in
                    // 按发布日期排序，最新的在前
                    version1.datePublished > version2.datePublished
                }
        } catch {
            let globalError = GlobalError.from(error)
            GlobalErrorHandler.shared.handle(globalError)
        }

        isLoadingModPackVersions = false
    }

    // MARK: - File Operations

    func downloadModPackFile(
        file: ModrinthVersionFile,
        projectDetail: ModrinthProjectDetail
    ) async -> URL? {
        do {
            // 创建临时目录
            let tempDir = try createTempDirectory(for: "modpack_download")
            let savePath = tempDir.appendingPathComponent(file.filename)

            // 重置下载进度
            modPackDownloadProgress = 0
            modPackTotalSize = 0

            // 使用支持进度回调的下载方法
            do {
                _ = try await downloadFileWithProgress(
                    urlString: file.url,
                    destinationURL: savePath,
                    expectedSha1: file.hashes.sha1
                )
                return savePath
            } catch {
                let globalError = GlobalError.from(error)
                handleDownloadError(
                    globalError.chineseMessage,
                    globalError.i18nKey
                )
                return nil
            }
        } catch {
            let globalError = GlobalError.from(error)
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }
    /// 下载文件并支持进度回调
    private func downloadFileWithProgress(
        urlString: String,
        destinationURL: URL,
        expectedSha1: String?
    ) async throws -> URL {
        // 创建 URL
        guard let url = URL(string: urlString) else {
            throw GlobalError.validation(
                chineseMessage: "无效的下载地址",
                i18nKey: "error.validation.invalid_download_url",
                level: .notification
            )
        }

        // 应用代理（如果需要）
        let finalURL: URL = {
            if let host = url.host,
               host == "github.com" || host == "raw.githubusercontent.com" {
                return URLConfig.applyGitProxyIfNeeded(url)
            }
            return url
        }()

        // 创建目标目录
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // 检查文件是否已存在
        if fileManager.fileExists(atPath: destinationURL.path) {
            if let expectedSha1 = expectedSha1, !expectedSha1.isEmpty {
                let actualSha1 = try DownloadManager.calculateFileSHA1(at: destinationURL)
                if actualSha1 == expectedSha1 {
                    // 文件已存在且校验通过，设置进度为完成
                    if let attributes = try? fileManager.attributesOfItem(atPath: destinationURL.path),
                       let fileSize = attributes[.size] as? Int64 {
                        modPackTotalSize = fileSize
                        modPackDownloadProgress = fileSize
                    }
                    return destinationURL
                }
            } else {
                // 没有 SHA1 校验，直接返回
                if let attributes = try? fileManager.attributesOfItem(atPath: destinationURL.path),
                   let fileSize = attributes[.size] as? Int64 {
                    modPackTotalSize = fileSize
                    modPackDownloadProgress = fileSize
                }
                return destinationURL
            }
        }

        // 获取文件大小
        let fileSize = try await getFileSize(from: finalURL)
        modPackTotalSize = fileSize

        // 创建进度跟踪器
        let progressCallback: (Int64, Int64) -> Void = { [weak self] downloadedBytes, totalBytes in
            Task { @MainActor in
                self?.modPackDownloadProgress = downloadedBytes
                if totalBytes > 0 {
                    self?.modPackTotalSize = totalBytes
                }
            }
        }
        let progressTracker = ModPackDownloadProgressTracker(
            totalSize: fileSize,
            progressCallback: progressCallback
        )

        // 创建 URLSession
        let config = URLSessionConfiguration.default
        let session = URLSession(
            configuration: config,
            delegate: progressTracker,
            delegateQueue: nil
        )

        // 下载文件
        return try await withCheckedThrowingContinuation { continuation in
            progressTracker.completionHandler = { result in
                switch result {
                case .success(let tempURL):
                    do {
                        // SHA1 校验
                        if let expectedSha1 = expectedSha1, !expectedSha1.isEmpty {
                            let actualSha1 = try DownloadManager.calculateFileSHA1(at: tempURL)
                            if actualSha1 != expectedSha1 {
                                throw GlobalError.validation(
                                    chineseMessage: "SHA1 校验失败",
                                    i18nKey: "error.validation.sha1_check_failed",
                                    level: .notification
                                )
                            }
                        }

                        // 移动文件到目标位置
                        if fileManager.fileExists(atPath: destinationURL.path) {
                            try fileManager.replaceItem(
                                at: destinationURL,
                                withItemAt: tempURL,
                                backupItemName: nil,
                                options: [],
                                resultingItemURL: nil
                            )
                        } else {
                            try fileManager.moveItem(at: tempURL, to: destinationURL)
                        }

                        continuation.resume(returning: destinationURL)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let downloadTask = session.downloadTask(with: finalURL)
            downloadTask.resume()
        }
    }

    /// 获取远程文件大小
    private func getFileSize(from url: URL) async throws -> Int64 {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GlobalError.download(
                chineseMessage: "无法获取文件大小",
                i18nKey: "error.download.cannot_get_file_size",
                level: .notification
            )
        }

        guard let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length"),
              let fileSize = Int64(contentLength) else {
            throw GlobalError.download(
                chineseMessage: "无法获取文件大小",
                i18nKey: "error.download.cannot_get_file_size",
                level: .notification
            )
        }

        return fileSize
    }
    func downloadGameIcon(
        projectDetail: ModrinthProjectDetail,
        gameName: String
    ) async -> String? {
        do {
            // 验证图标URL
            guard let iconUrl = projectDetail.iconUrl else {
                return nil
            }

            // 获取游戏目录
            let gameDirectory = AppPaths.profileDirectory(gameName: gameName)

            // 确保游戏目录存在
            try FileManager.default.createDirectory(
                at: gameDirectory,
                withIntermediateDirectories: true
            )

            // 确定图标文件名和路径
            let iconFileName = "default_game_icon.png"
            let iconPath = gameDirectory.appendingPathComponent(iconFileName)

            // 使用 DownloadManager 下载图标文件（已包含错误处理和临时文件清理）
            do {
                _ = try await DownloadManager.downloadFile(
                    urlString: iconUrl,
                    destinationURL: iconPath,
                    expectedSha1: nil
                )
                return iconFileName
            } catch {
                handleDownloadError(
                    "下载游戏图标失败",
                    "error.network.icon_download_failed"
                )
                return nil
            }
        } catch {
            handleDownloadError(
                "下载游戏图标失败",
                "error.network.icon_download_failed"
            )
            return nil
        }
    }

    func extractModPack(modPackPath: URL) async -> URL? {
        do {
            let fileExtension = modPackPath.pathExtension.lowercased()

            // 检查文件格式
            guard fileExtension == "zip" || fileExtension == "mrpack" else {
                handleDownloadError(
                    "不支持的整合包格式: \(fileExtension)",
                    "error.resource.unsupported_modpack_format"
                )
                return nil
            }

            // 检查源文件是否存在
            let modPackPathString = modPackPath.path
            guard FileManager.default.fileExists(atPath: modPackPathString)
            else {
                handleDownloadError(
                    "整合包文件不存在: \(modPackPathString)",
                    "error.filesystem.file_not_found"
                )
                return nil
            }

            // 获取源文件大小
            let sourceAttributes = try FileManager.default.attributesOfItem(
                atPath: modPackPathString
            )
            let sourceSize = sourceAttributes[.size] as? Int64 ?? 0

            guard sourceSize > 0 else {
                handleDownloadError("整合包文件为空", "error.resource.modpack_empty")
                return nil
            }

            // 创建临时解压目录
            let tempDir = try createTempDirectory(for: "modpack_extraction")

            // 使用 ZIPFoundation 解压文件
            try FileManager.default.unzipItem(at: modPackPath, to: tempDir)

            // 仅保留关键日志
            return tempDir
        } catch {
            handleDownloadError(
                "解压整合包失败: \(error.localizedDescription)",
                "error.filesystem.extraction_failed"
            )
            return nil
        }
    }

    func parseModrinthIndex(extractedPath: URL) async -> ModrinthIndexInfo? {
        // 首先尝试解析 Modrinth 格式
        if let modrinthInfo = await parseModrinthIndexInternal(extractedPath: extractedPath) {
            return modrinthInfo
        }

        // 如果不是 Modrinth 格式，尝试解析 CurseForge 格式
        if let modrinthInfo = await CurseForgeManifestParser.parseManifest(extractedPath: extractedPath) {
            // 设置 lastParsedIndexInfo 以便显示 mod 加载器进度条
            lastParsedIndexInfo = modrinthInfo
            return modrinthInfo
        }

        // 都不是支持的格式
        handleDownloadError(
            "不支持的整合包格式，请使用 Modrinth (.mrpack) 或 CurseForge (.zip) 格式的整合包",
            "error.resource.unsupported_modpack_format"
        )
        return nil
    }

    private func parseModrinthIndexInternal(extractedPath: URL) async -> ModrinthIndexInfo? {
        do {
            // 查找并解析 modrinth.index.json
            let indexPath = extractedPath.appendingPathComponent(
                AppConstants.modrinthIndexFileName
            )

            let indexPathString = indexPath.path
            guard FileManager.default.fileExists(atPath: indexPathString) else {
                return nil
            }

            // 获取文件大小
            let fileAttributes = try FileManager.default.attributesOfItem(
                atPath: indexPathString
            )
            let fileSize = fileAttributes[.size] as? Int64 ?? 0

            guard fileSize > 0 else {
                handleDownloadError(
                    "modrinth.index.json 文件为空",
                    "error.resource.modrinth_index_empty"
                )
                return nil
            }

            // 使用局部作用域确保中间变量尽早释放
            let indexInfo: ModrinthIndexInfo = try {
                let indexData = try Data(contentsOf: indexPath)

                // 尝试解析 JSON
                let modPackIndex = try JSONDecoder().decode(
                    ModrinthIndex.self,
                    from: indexData
                )

                // 确定加载器类型和版本
                let loaderInfo = determineLoaderInfo(
                    from: modPackIndex.dependencies
                )

                // 创建解析结果
                let info = ModrinthIndexInfo(
                    gameVersion: modPackIndex.dependencies.minecraft ?? "unknown",
                    loaderType: loaderInfo.type,
                    loaderVersion: loaderInfo.version,
                    modPackName: modPackIndex.name,
                    modPackVersion: modPackIndex.versionId,
                    summary: modPackIndex.summary,
                    files: modPackIndex.files,
                    dependencies: modPackIndex.dependencies.dependencies ?? []
                )
                // indexData 和 modPackIndex 在此作用域结束后会自动释放
                return info
            }()

            lastParsedIndexInfo = indexInfo

            // 仅保留关键日志
            return indexInfo
        } catch {
            // 仅记录错误日志
            if error is DecodingError {
                Logger.shared.error("解析 modrinth.index.json 失败: JSON 格式错误")
            }
            return nil
        }
    }

    // MARK: - Helper Methods

    private func createTempDirectory(for purpose: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(purpose)
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        return tempDir
    }

    private func validateFileSize(
        tempFileURL: URL,
        httpResponse: HTTPURLResponse
    ) -> Bool {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(
                atPath: tempFileURL.path
            )
            let actualSize = fileAttributes[.size] as? Int64 ?? 0

            if let expectedSize = httpResponse.value(
                forHTTPHeaderField: "Content-Length"
            ), let expectedSizeInt = Int64(expectedSize), actualSize != expectedSizeInt {
                handleDownloadError(
                    "文件大小不匹配，预期: \(expectedSizeInt)，实际: \(actualSize)",
                    "error.resource.size_mismatch"
                )
                return false
            }
            return true
        } catch {
            handleDownloadError(
                "无法获取文件大小: \(error.localizedDescription)",
                "error.filesystem.file_read_failed"
            )
            return false
        }
    }

    private func validateFileIntegrity(
        tempFileURL: URL,
        expectedSha1: String
    ) -> Bool {
        do {
            let actualSha1 = try SHA1Calculator.sha1(ofFileAt: tempFileURL)
            if actualSha1 != expectedSha1 {
                handleDownloadError(
                    "文件校验失败，SHA1不匹配",
                    "error.resource.sha1_mismatch"
                )
                return false
            }
            return true
        } catch {
            handleDownloadError(
                "SHA1校验失败: \(error.localizedDescription)",
                "error.validation.sha1_check_failed"
            )
            return false
        }
    }

    private func handleDownloadError(_ message: String, _ i18nKey: String) {
        let globalError = GlobalError.resource(
            chineseMessage: message,
            i18nKey: i18nKey,
            level: .notification
        )
        GlobalErrorHandler.shared.handle(globalError)
    }

    private func determineLoaderInfo(
        from dependencies: ModrinthIndexDependencies
    ) -> (type: String, version: String) {
        // 检查各种加载器，按优先级排序
        // 优先检查带 -loader 后缀的格式
        if let forgeVersion = dependencies.forgeLoader {
            return ("forge", forgeVersion)
        } else if let fabricVersion = dependencies.fabricLoader {
            return ("fabric", fabricVersion)
        } else if let quiltVersion = dependencies.quiltLoader {
            return ("quilt", quiltVersion)
        } else if let neoforgeVersion = dependencies.neoforgeLoader {
            return ("neoforge", neoforgeVersion)
        }

        // 检查不带 -loader 后缀的格式
        if let forgeVersion = dependencies.forge {
            return ("forge", forgeVersion)
        } else if let fabricVersion = dependencies.fabric {
            return ("fabric", fabricVersion)
        } else if let quiltVersion = dependencies.quilt {
            return ("quilt", quiltVersion)
        } else if let neoforgeVersion = dependencies.neoforge {
            return ("neoforge", neoforgeVersion)
        }

        // 默认返回 vanilla
        return ("vanilla", "unknown")
    }
}
// MARK: - Modrinth Index Models
struct ModrinthIndex: Codable {
    let formatVersion: Int
    let game: String
    let versionId: String
    let name: String
    let summary: String?
    let files: [ModrinthIndexFile]
    let dependencies: ModrinthIndexDependencies

    enum CodingKeys: String, CodingKey {
        case formatVersion = "formatVersion"
        case game
        case versionId = "versionId"
        case name
        case summary
        case files
        case dependencies
    }
}

// MARK: - File Hashes (优化内存使用)
/// 优化的文件哈希结构，使用结构体替代字典以减少内存占用
/// 常用哈希（sha1, sha512）作为属性存储，其他哈希存储在可选字典中
struct ModrinthIndexFileHashes: Codable {
    /// SHA1 哈希（最常用）
    let sha1: String?
    /// SHA512 哈希（次常用）
    let sha512: String?
    /// 其他哈希类型（不常用，延迟存储）
    let other: [String: String]?

    /// 从字典创建（用于 JSON 解码）
    init(from dict: [String: String]) {
        self.sha1 = dict["sha1"]
        self.sha512 = dict["sha512"]

        // 只存储非标准哈希
        var otherDict: [String: String] = [:]
        for (key, value) in dict {
            if key != "sha1" && key != "sha512" {
                otherDict[key] = value
            }
        }
        self.other = otherDict.isEmpty ? nil : otherDict
    }

    /// 自定义解码，从 JSON 字典解码
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: String].self)
        self.init(from: dict)
    }

    /// 编码为字典格式（用于 JSON 编码）
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        var dict: [String: String] = [:]

        if let sha1 = sha1 {
            dict["sha1"] = sha1
        }
        if let sha512 = sha512 {
            dict["sha512"] = sha512
        }
        if let other = other {
            dict.merge(other) { _, new in new }
        }

        try container.encode(dict)
    }

    /// 字典访问兼容性（向后兼容）
    subscript(key: String) -> String? {
        switch key {
        case "sha1": return sha1
        case "sha512": return sha512
        default: return other?[key]
        }
    }
}

struct ModrinthIndexFile: Codable {
    let path: String
    let hashes: ModrinthIndexFileHashes
    let downloads: [String]
    let fileSize: Int
    let env: ModrinthIndexFileEnv?
    let source: FileSource?
    // CurseForge 特有字段，用于延迟获取文件详情
    let curseForgeProjectId: Int?
    let curseForgeFileId: Int?

    enum CodingKeys: String, CodingKey {
        case path
        case hashes
        case downloads
        case fileSize = "fileSize"
        case env
        case source
        case curseForgeProjectId
        case curseForgeFileId
    }

    // 为兼容性提供默认初始化器
    init(
        path: String,
        hashes: ModrinthIndexFileHashes,
        downloads: [String],
        fileSize: Int,
        env: ModrinthIndexFileEnv? = nil,
        source: FileSource? = nil,
        curseForgeProjectId: Int? = nil,
        curseForgeFileId: Int? = nil
    ) {
        self.path = path
        self.hashes = hashes
        self.downloads = downloads
        self.fileSize = fileSize
        self.env = env
        self.source = source
        self.curseForgeProjectId = curseForgeProjectId
        self.curseForgeFileId = curseForgeFileId
    }

    // 兼容旧版本字典格式的初始化器
    init(
        path: String,
        hashes: [String: String],
        downloads: [String],
        fileSize: Int,
        env: ModrinthIndexFileEnv? = nil,
        source: FileSource? = nil,
        curseForgeProjectId: Int? = nil,
        curseForgeFileId: Int? = nil
    ) {
        self.path = path
        self.hashes = ModrinthIndexFileHashes(from: hashes)
        self.downloads = downloads
        self.fileSize = fileSize
        self.env = env
        self.source = source
        self.curseForgeProjectId = curseForgeProjectId
        self.curseForgeFileId = curseForgeFileId
    }
}

enum FileSource: String, Codable {
    case modrinth = "modrinth"
    case curseforge = "curseforge"
}

struct ModrinthIndexFileEnv: Codable {
    let client: String?
    let server: String?
}

struct ModrinthIndexDependencies: Codable {
    let minecraft: String?
    let forgeLoader: String?
    let fabricLoader: String?
    let quiltLoader: String?
    let neoforgeLoader: String?
    // 添加不带 -loader 后缀的属性
    let forge: String?
    let fabric: String?
    let quilt: String?
    let neoforge: String?
    let dependencies: [ModrinthIndexProjectDependency]?

    enum CodingKeys: String, CodingKey {
        case minecraft
        case forgeLoader = "forge-loader"
        case fabricLoader = "fabric-loader"
        case quiltLoader = "quilt-loader"
        case neoforgeLoader = "neoforge-loader"
        case forge
        case fabric
        case quilt
        case neoforge
        case dependencies
    }
}

struct ModrinthIndexProjectDependency: Codable {
    let projectId: String?
    let versionId: String?
    let dependencyType: String

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case versionId = "version_id"
        case dependencyType = "dependency_type"
    }
}

// MARK: - Modrinth Index Info
struct ModrinthIndexInfo {
    let gameVersion: String
    let loaderType: String
    let loaderVersion: String
    let modPackName: String
    let modPackVersion: String
    let summary: String?
    let files: [ModrinthIndexFile]
    let dependencies: [ModrinthIndexProjectDependency]
    let source: FileSource

    init(
        gameVersion: String,
        loaderType: String,
        loaderVersion: String,
        modPackName: String,
        modPackVersion: String,
        summary: String?,
        files: [ModrinthIndexFile],
        dependencies: [ModrinthIndexProjectDependency],
        source: FileSource = .modrinth
    ) {
        self.gameVersion = gameVersion
        self.loaderType = loaderType
        self.loaderVersion = loaderVersion
        self.modPackName = modPackName
        self.modPackVersion = modPackVersion
        self.summary = summary
        self.files = files
        self.dependencies = dependencies
        self.source = source
    }
}
// MARK: - ModPack Install State
@MainActor
class ModPackInstallState: ObservableObject {
    @Published var isInstalling = false
    @Published var filesProgress: Double = 0
    @Published var dependenciesProgress: Double = 0
    @Published var overridesProgress: Double = 0
    @Published var currentFile: String = ""
    @Published var currentDependency: String = ""
    @Published var currentOverride: String = ""
    @Published var filesTotal: Int = 0
    @Published var dependenciesTotal: Int = 0
    @Published var overridesTotal: Int = 0
    @Published var filesCompleted: Int = 0
    @Published var dependenciesCompleted: Int = 0
    @Published var overridesCompleted: Int = 0

    func reset() {
        isInstalling = false
        filesProgress = 0
        dependenciesProgress = 0
        overridesProgress = 0
        currentFile = ""
        currentDependency = ""
        currentOverride = ""
        filesTotal = 0
        dependenciesTotal = 0
        overridesTotal = 0
        filesCompleted = 0
        dependenciesCompleted = 0
        overridesCompleted = 0
    }

    func startInstallation(
        filesTotal: Int,
        dependenciesTotal: Int,
        overridesTotal: Int = 0
    ) {
        self.filesTotal = filesTotal
        self.dependenciesTotal = dependenciesTotal
        // 只有在 overrides 还没有开始时才设置 total，避免覆盖已完成的进度
        if self.overridesTotal == 0 {
            self.overridesTotal = overridesTotal
        }
        self.isInstalling = true
        self.filesProgress = 0
        self.dependenciesProgress = 0
        // 只有在 overrides 还没有完成时才重置进度，保留已完成的 overrides 进度
        if self.overridesCompleted == 0 {
            self.overridesProgress = 0
        }
        self.filesCompleted = 0
        self.dependenciesCompleted = 0
        // 保留已完成的 overrides 进度，不重置
    }

    func updateFilesProgress(fileName: String, completed: Int, total: Int) {
        currentFile = fileName
        filesCompleted = completed
        filesTotal = total
        filesProgress = calculateProgress(completed: completed, total: total)
        objectWillChange.send()
    }

    func updateDependenciesProgress(
        dependencyName: String,
        completed: Int,
        total: Int
    ) {
        currentDependency = dependencyName
        dependenciesCompleted = completed
        dependenciesTotal = total
        dependenciesProgress = calculateProgress(
            completed: completed,
            total: total
        )
        objectWillChange.send()
    }

    func updateOverridesProgress(
        overrideName: String,
        completed: Int,
        total: Int
    ) {
        currentOverride = overrideName
        overridesCompleted = completed
        overridesTotal = total
        overridesProgress = calculateProgress(
            completed: completed,
            total: total
        )
        objectWillChange.send()
    }

    private func calculateProgress(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0.0 }
        return max(0.0, min(1.0, Double(completed) / Double(total)))
    }
}
// MARK: - Download Progress Tracker
private class ModPackDownloadProgressTracker: NSObject, URLSessionDownloadDelegate {
    private let progressCallback: (Int64, Int64) -> Void
    private let totalFileSize: Int64
    var completionHandler: ((Result<URL, Error>) -> Void)?

    init(totalSize: Int64, progressCallback: @escaping (Int64, Int64) -> Void) {
        self.totalFileSize = totalSize
        self.progressCallback = progressCallback
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let actualTotalSize = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : totalFileSize
        if actualTotalSize > 0 {
            DispatchQueue.main.async { [weak self] in
                self?.progressCallback(totalBytesWritten, actualTotalSize)
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        completionHandler?(.success(location))
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            completionHandler?(.failure(error))
        }
    }
}
