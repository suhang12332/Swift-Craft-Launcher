//
//  LauncherImportViewModel.swift
//  SwiftCraftLauncher
//
//

import SwiftUI

/// 启动器导入 ViewModel
@MainActor
class LauncherImportViewModel: BaseGameFormViewModel {

    // MARK: - Published Properties

    @Published var selectedLauncherType: ImportLauncherType = .multiMC
    @Published var selectedInstancePath: URL?  // 直接选择的实例路径（所有启动器都使用此方式）
    @Published var isImporting = false {
        didSet {
            updateParentState()
        }
    }
    @Published var importProgress: (fileName: String, completed: Int, total: Int)?

    // MARK: - Private Properties

    var gameRepository: GameRepository?
    var playerListViewModel: PlayerListViewModel?
    var copyTask: Task<Void, Error>?

    // MARK: - Initialization

    override init(configuration: GameFormConfiguration) {
        super.init(configuration: configuration)
    }

    // MARK: - Setup Methods

    func setup(gameRepository: GameRepository, playerListViewModel: PlayerListViewModel) {
        self.gameRepository = gameRepository
        self.playerListViewModel = playerListViewModel
        updateParentState()
    }

    // MARK: - Cleanup Methods

    /// 清理缓存和状态（在 sheet 关闭时调用）
    func cleanup() {
        // 取消正在进行的任务
        copyTask?.cancel()
        copyTask = nil
        downloadTask?.cancel()
        downloadTask = nil

        // 重置状态
        selectedInstancePath = nil
        importProgress = nil
        isImporting = false
        selectedLauncherType = .multiMC

        // 清理游戏名（可选，根据需求决定是否保留）
        // gameNameValidator.gameName = ""

        // 重置下载状态
        gameSetupService.downloadState.reset()

        // 清理引用
        gameRepository = nil
        playerListViewModel = nil
    }

    // MARK: - Override Methods

    override func performConfirmAction() async {
        // 所有启动器都直接使用 selectedInstancePath
        if let instancePath = selectedInstancePath {
            startDownloadTask {
                await self.importSelectedInstancePath(instancePath)
            }
        }
    }

    override func handleCancel() {
        if isDownloading || isImporting {
            // 取消复制任务
            copyTask?.cancel()
            copyTask = nil
            // 取消下载任务
            downloadTask?.cancel()
            downloadTask = nil
            gameSetupService.downloadState.cancel()
            Task {
                await performCancelCleanup()
            }
        } else {
            configuration.actions.onCancel()
        }
    }

    override func performCancelCleanup() async {
        // 清理已创建的游戏文件夹
        if let instancePath = selectedInstancePath {
            // 从实例路径推断启动器基础路径
            let basePath = inferBasePath(from: instancePath)

            let parser = LauncherInstanceParserFactory.createParser(for: selectedLauncherType)
            if let info = try? parser.parseInstance(at: instancePath, basePath: basePath) {
                do {
                    let fileManager = MinecraftFileManager()
                    // 使用用户输入的游戏名（如果有），否则使用实例的游戏名
                    let gameName = gameNameValidator.gameName.isEmpty
                        ? info.gameName
                        : gameNameValidator.gameName
                    try fileManager.cleanupGameDirectories(gameName: gameName)
                } catch {
                    Logger.shared.error("清理游戏文件夹失败: \(error.localizedDescription)")
                }
            }
        }

        await MainActor.run {
            isImporting = false
            importProgress = nil
            gameSetupService.downloadState.reset()
            configuration.actions.onCancel()
        }
    }

    override func computeIsDownloading() -> Bool {
        return gameSetupService.downloadState.isDownloading || isImporting
    }

    override func computeIsFormValid() -> Bool {
        // 所有启动器都检查 selectedInstancePath
        guard selectedInstancePath != nil && gameNameValidator.isFormValid else {
            return false
        }

        // 检查 Mod Loader 是否支持
        return isModLoaderSupported
    }

    var shouldShowProgress: Bool {
        gameSetupService.downloadState.isDownloading || isImporting
    }

    var hasSelectedInstance: Bool {
        selectedInstancePath != nil
    }
}
