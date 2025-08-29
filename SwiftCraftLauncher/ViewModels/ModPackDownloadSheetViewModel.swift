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

    private var allModPackVersions: [ModrinthProjectDetailVersion] = []
    private var gameRepository: GameRepository?

    func setGameRepository(_ repository: GameRepository) {
        self.gameRepository = repository
    }

    // MARK: - Data Loading

    func loadProjectDetails(projectId: String) async {
        isLoadingProjectDetails = true

        do {
            projectDetail =
                try await ModrinthService.fetchProjectDetailsThrowing(
                    id: projectId
                )
            availableGameVersions = projectDetail?.gameVersions ?? []
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
            filteredModPackVersions = allModPackVersions.filter { version in
                version.gameVersions.contains(gameVersion)
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
            // 验证下载链接
            guard let url = URL(string: file.url) else {
                handleDownloadError(
                    "无效的下载链接: \(file.url)",
                    "error.validation.invalid_download_url"
                )
                return nil
            }

            // 创建临时目录
            let tempDir = try createTempDirectory(for: "modpack_download")
            let savePath = tempDir.appendingPathComponent(file.filename)

            // 下载文件
            let (tempFileURL, response) = try await URLSession.shared.download(
                from: url
            )
            defer { try? FileManager.default.removeItem(at: tempFileURL) }

            // 验证响应
            guard let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200
            else {
                handleDownloadError(
                    "下载失败，HTTP状态码: \((response as? HTTPURLResponse)?.statusCode ?? 0)",
                    "error.network.download_failed"
                )
                return nil
            }

            // 验证文件大小
            if !validateFileSize(
                tempFileURL: tempFileURL,
                httpResponse: httpResponse
            ) {
                return nil
            }

            // 验证文件完整性
            if !validateFileIntegrity(
                tempFileURL: tempFileURL,
                expectedSha1: file.hashes.sha1
            ) {
                return nil
            }

            // 移动到临时目录
            try FileManager.default.moveItem(at: tempFileURL, to: savePath)

            Logger.shared.info("整合包下载成功: \(file.filename) -> \(savePath.path)")
            return savePath
        } catch {
            let globalError = GlobalError.from(error)
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    func downloadGameIcon(
        projectDetail: ModrinthProjectDetail,
        gameName: String
    ) async -> String? {
        do {
            // 验证图标URL
            guard let iconUrl = projectDetail.iconUrl,
                let url = URL(string: iconUrl)
            else {
                Logger.shared.warning("项目没有图标URL或URL无效: \(projectDetail.title)")
                return nil
            }

            // 获取游戏目录
            guard
                let gameDirectory = AppPaths.profileDirectory(
                    gameName: gameName
                )
            else {
                handleDownloadError(
                    "无法获取游戏目录: \(gameName)",
                    "error.configuration.game_directory_not_found"
                )
                return nil
            }

            // 确保游戏目录存在
            try FileManager.default.createDirectory(
                at: gameDirectory,
                withIntermediateDirectories: true
            )

            // 确定图标文件名和路径
            let iconFileName = "default_game_icon.png"
            let iconPath = gameDirectory.appendingPathComponent(iconFileName)

            // 下载图标文件
            let (tempFileURL, response) = try await URLSession.shared.download(
                from: url
            )
            defer { try? FileManager.default.removeItem(at: tempFileURL) }

            // 验证响应
            guard let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200
            else {
                handleDownloadError(
                    "下载游戏图标失败，HTTP状态码: \((response as? HTTPURLResponse)?.statusCode ?? 0)",
                    "error.network.icon_download_failed"
                )
                return nil
            }

            // 验证文件大小
            let fileAttributes = try FileManager.default.attributesOfItem(
                atPath: tempFileURL.path
            )
            let actualSize = fileAttributes[.size] as? Int64 ?? 0

            guard actualSize > 0 else {
                handleDownloadError("下载的游戏图标文件为空", "error.resource.icon_empty")
                return nil
            }

            // 如果目标文件已存在，先删除
            if FileManager.default.fileExists(atPath: iconPath.path) {
                try FileManager.default.removeItem(at: iconPath)
            }

            // 直接移动到游戏目录（保存为 PNG）
            try FileManager.default.moveItem(at: tempFileURL, to: iconPath)

            Logger.shared.info(
                "游戏图标下载成功: \(projectDetail.title) -> \(iconPath.path)"
            )
            return iconFileName
        } catch {
            Logger.shared.error("下载游戏图标详细错误: \(error)")
            handleDownloadError(
                "下载游戏图标失败: \(error.localizedDescription)",
                "error.network.icon_download_failed"
            )
            return nil
        }
    }

    func extractModPack(modPackPath: URL) async -> URL? {
        do {
            let fileExtension = modPackPath.pathExtension.lowercased()

            Logger.shared.info("开始解压整合包: \(modPackPath.lastPathComponent)")

            // 检查文件格式
            guard fileExtension == "zip" || fileExtension == "mrpack" else {
                handleDownloadError(
                    "不支持的整合包格式: \(fileExtension)",
                    "error.resource.unsupported_modpack_format"
                )
                return nil
            }

            // 检查源文件是否存在
            guard FileManager.default.fileExists(atPath: modPackPath.path)
            else {
                handleDownloadError(
                    "整合包文件不存在: \(modPackPath.path)",
                    "error.filesystem.file_not_found"
                )
                return nil
            }

            // 获取源文件大小
            let sourceAttributes = try FileManager.default.attributesOfItem(
                atPath: modPackPath.path
            )
            let sourceSize = sourceAttributes[.size] as? Int64 ?? 0
            Logger.shared.info("整合包文件大小: \(sourceSize) 字节")

            guard sourceSize > 0 else {
                handleDownloadError("整合包文件为空", "error.resource.modpack_empty")
                return nil
            }

            // 创建临时解压目录
            let tempDir = try createTempDirectory(for: "modpack_extraction")

            Logger.shared.info("创建临时解压目录: \(tempDir.path)")

            // 使用 ZIPFoundation 解压文件
            try FileManager.default.unzipItem(at: modPackPath, to: tempDir)

            // 验证解压结果
            let contents = try FileManager.default.contentsOfDirectory(
                at: tempDir,
                includingPropertiesForKeys: nil
            )
            Logger.shared.info(
                "解压完成，目录内容: \(contents.map { $0.lastPathComponent })"
            )

            // 检查是否包含 modrinth.index.json
            let indexPath = tempDir.appendingPathComponent(
                "modrinth.index.json"
            )
            if FileManager.default.fileExists(atPath: indexPath.path) {
                Logger.shared.info("找到 modrinth.index.json 文件")
            } else {
                Logger.shared.warning("解压后未找到 modrinth.index.json 文件")
            }

            Logger.shared.info(
                "整合包解压成功: \(modPackPath.lastPathComponent) -> \(tempDir.path)"
            )
            return tempDir
        } catch {
            Logger.shared.error("解压整合包详细错误: \(error)")
            handleDownloadError(
                "解压整合包失败: \(error.localizedDescription)",
                "error.filesystem.extraction_failed"
            )
            return nil
        }
    }

    func parseModrinthIndex(extractedPath: URL) async -> ModrinthIndexInfo? {
        do {
            // 查找并解析 modrinth.index.json
            let indexPath = extractedPath.appendingPathComponent(
                "modrinth.index.json"
            )

            Logger.shared.info("尝试解析 modrinth.index.json: \(indexPath.path)")

            guard FileManager.default.fileExists(atPath: indexPath.path) else {
                // 列出解压目录中的文件，帮助调试
                do {
                    let contents = try FileManager.default.contentsOfDirectory(
                        at: extractedPath,
                        includingPropertiesForKeys: nil
                    )
                    Logger.shared.info(
                        "解压目录内容: \(contents.map { $0.lastPathComponent })"
                    )
                } catch {
                    Logger.shared.error(
                        "无法列出解压目录内容: \(error.localizedDescription)"
                    )
                }

                handleDownloadError(
                    "整合包中未找到 modrinth.index.json 文件",
                    "error.resource.modrinth_index_not_found"
                )
                return nil
            }

            // 获取文件大小
            let fileAttributes = try FileManager.default.attributesOfItem(
                atPath: indexPath.path
            )
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            Logger.shared.info("modrinth.index.json 文件大小: \(fileSize) 字节")

            guard fileSize > 0 else {
                handleDownloadError(
                    "modrinth.index.json 文件为空",
                    "error.resource.modrinth_index_empty"
                )
                return nil
            }

            let indexData = try Data(contentsOf: indexPath)
            Logger.shared.info(
                "成功读取 modrinth.index.json 数据，大小: \(indexData.count) 字节"
            )

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
            let indexInfo = ModrinthIndexInfo(
                gameVersion: modPackIndex.dependencies.minecraft ?? "unknown",
                loaderType: loaderInfo.type,
                loaderVersion: loaderInfo.version,
                modPackName: modPackIndex.name,
                modPackVersion: modPackIndex.versionId,
                summary: modPackIndex.summary,
                files: modPackIndex.files,
                dependencies: modPackIndex.dependencies.dependencies ?? []
            )

            lastParsedIndexInfo = indexInfo
            Logger.shared.info(
                "解析 modrinth.index.json 成功: \(modPackIndex.name) v\(modPackIndex.versionId)"
            )

            return indexInfo
        } catch {
            Logger.shared.error("解析 modrinth.index.json 详细错误: \(error)")

            // 如果是 JSON 解析错误，尝试显示部分内容
            if let jsonError = error as? DecodingError {
                Logger.shared.error("JSON 解析错误: \(jsonError)")
            }

            handleDownloadError(
                "解析 modrinth.index.json 失败: \(error.localizedDescription)",
                "error.resource.modrinth_index_parse_failed"
            )
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

struct ModrinthIndexFile: Codable {
    let path: String
    let hashes: [String: String]
    let downloads: [String]
    let fileSize: Int
    let env: ModrinthIndexFileEnv?

    enum CodingKeys: String, CodingKey {
        case path
        case hashes
        case downloads
        case fileSize = "fileSize"
        case env
    }
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
        self.overridesTotal = overridesTotal
        self.isInstalling = true
        self.filesProgress = 0
        self.dependenciesProgress = 0
        self.overridesProgress = 0
        self.filesCompleted = 0
        self.dependenciesCompleted = 0
        self.overridesCompleted = 0
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
