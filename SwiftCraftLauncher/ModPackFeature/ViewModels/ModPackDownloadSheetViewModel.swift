//
//  ModPackDownloadSheetViewModel.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/8/3.
//
import Foundation
import SwiftUI

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

    @Published var isProcessing = false

    private var downloadTask: Task<Void, Never>?
    private let downloadService = ModPackDownloadService()
    private lazy var installCoordinator = ModPackInstallCoordinator(downloadService: downloadService)
    // MARK: - Memory Management
    /// 清理不再需要的索引数据以释放内存
    /// 在 ModPack 安装完成后调用
    func clearParsedIndexInfo() {
        lastParsedIndexInfo = nil
    }

    /// 清理所有整合包导入相关的数据和临时文件
    func cleanupAllData() {
        cancelDownloadAndResetStates()

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

    /// 清理临时文件（modpack_download 和 modpack_extraction 目录），在后台执行避免主线程阻塞
    func cleanupTempFiles() {
        downloadService.cleanupTempFiles()
    }

    private var allModPackVersions: [ModrinthProjectDetailVersion] = []
    private var gameRepository: GameRepository?

    func setGameRepository(_ repository: GameRepository) {
        self.gameRepository = repository
    }

    init() {
        downloadService.progressHandler = { [weak self] downloaded, total in
            guard let self else { return }
            Task { @MainActor in
                self.modPackDownloadProgress = downloaded
                if total > 0 {
                    self.modPackTotalSize = total
                }
            }
        }
        downloadService.errorHandler = { [weak self] message, i18nKey in
            guard let self else { return }
            Task { @MainActor in
                self.handleDownloadError(message, i18nKey)
            }
        }
    }

    // MARK: - Download / Install Pipeline

    func beginDownloadAndInstall(
        selectedVersion: ModrinthProjectDetailVersion,
        projectDetail: ModrinthProjectDetail,
        gameName: String,
        selectedGameVersion: String,
        gameSetupService: GameSetupUtil,
        onFinished: @escaping @MainActor (_ success: Bool) -> Void
    ) {
        downloadTask?.cancel()
        downloadTask = Task { [weak self] in
            guard let self else { return }
            let success = await self.performModPackDownloadAndInstall(
                selectedVersion: selectedVersion,
                projectDetail: projectDetail,
                gameName: gameName,
                selectedGameVersion: selectedGameVersion,
                gameSetupService: gameSetupService
            )
            onFinished(success)
        }
    }

    func cancelDownloadAndResetStates(gameSetupService: GameSetupUtil? = nil) {
        downloadTask?.cancel()
        downloadTask = nil
        isProcessing = false
        modPackInstallState.reset()
        if let gameSetupService {
            gameSetupService.downloadState.reset()
        }
    }

    func cleanupGameDirectoriesForCancel(gameName: String) async {
        await cleanupGameDirectories(gameName: gameName)
    }

    private func cleanupGameDirectories(gameName: String) async {
        do {
            let fileManager = MinecraftFileManager()
            try fileManager.cleanupGameDirectories(gameName: gameName)
        } catch {
            Logger.shared.error("清理游戏文件夹失败: \(error.localizedDescription)")
        }
    }

    private func performModPackDownloadAndInstall(
        selectedVersion: ModrinthProjectDetailVersion,
        projectDetail: ModrinthProjectDetail,
        gameName: String,
        selectedGameVersion: String,
        gameSetupService: GameSetupUtil
    ) async -> Bool {
        guard let gameRepository else {
            return false
        }

        let success = await installCoordinator.run(
            .init(
                selectedVersion: selectedVersion,
                projectDetail: projectDetail,
                gameName: gameName,
                selectedGameVersion: selectedGameVersion,
                gameSetupService: gameSetupService,
                gameRepository: gameRepository,
                modPackInstallState: modPackInstallState,
                setProcessing: { [weak self] processing in
                    self?.isProcessing = processing
                },
                setLastParsedIndexInfo: { [weak self] info in
                    self?.lastParsedIndexInfo = info
                }
            )
        )

        if success {
            clearParsedIndexInfo()
        } else {
            clearParsedIndexInfo()
        }

        return success
    }

    /// 应用预加载的项目详情，避免在 sheet 内重复加载
    func applyPreloadedDetail(_ detail: ModrinthProjectDetail) {
        projectDetail = detail
        let filteredVersions = detail.gameVersions.filter { CommonUtil.isVersionAtLeast($0) }
        availableGameVersions = CommonUtil.sortMinecraftVersions(filteredVersions)
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
            let filteredVersions = gameVersions.filter { CommonUtil.isVersionAtLeast($0) }
            availableGameVersions = CommonUtil.sortMinecraftVersions(filteredVersions)
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
        modPackDownloadProgress = 0
        modPackTotalSize = 0
        return await downloadService.downloadModPackFile(file: file, projectDetail: projectDetail)
    }
    func downloadGameIcon(
        projectDetail: ModrinthProjectDetail,
        gameName: String
    ) async -> String? {
        await downloadService.downloadGameIcon(projectDetail: projectDetail, gameName: gameName)
    }

    func extractModPack(modPackPath: URL) async -> URL? {
        await downloadService.extractModPack(modPackPath: modPackPath)
    }

    func parseModrinthIndex(extractedPath: URL) async -> ModrinthIndexInfo? {
        if let info = await ModPackIndexParser.parseIndex(extractedPath: extractedPath) {
            lastParsedIndexInfo = info
            return info
        }
        handleDownloadError(
            "不支持的整合包格式，请使用 Modrinth (.mrpack) 或 CurseForge (.zip) 格式的整合包",
            "error.resource.unsupported_modpack_format"
        )
        return nil
    }

    private func handleDownloadError(_ message: String, _ i18nKey: String) {
        let globalError = GlobalError.resource(
            chineseMessage: message,
            i18nKey: i18nKey,
            level: .notification
        )
        GlobalErrorHandler.shared.handle(globalError)
    }
}
