//
//  ModPackImportViewModel.swift
//  SwiftCraftLauncher
//
//

import SwiftUI

// MARK: - ModPack Import View Model
@MainActor
class ModPackImportViewModel: BaseGameFormViewModel {
    let modPackViewModel = ModPackDownloadSheetViewModel()

    @Published var selectedModPackFile: URL?
    @Published var extractedModPackPath: URL?
    @Published var modPackIndexInfo: ModrinthIndexInfo?
    @Published var isProcessingModPack = false

    let onProcessingStateChanged: (Bool) -> Void
    var gameRepository: GameRepository?

    // MARK: - Initialization
    init(
        configuration: GameFormConfiguration,
        preselectedFile: URL? = nil,
        shouldStartProcessing: Bool = false,
        onProcessingStateChanged: @escaping (Bool) -> Void = { _ in },
        errorHandler: GlobalErrorHandler = AppServices.errorHandler
    ) {
        self.onProcessingStateChanged = onProcessingStateChanged
        super.init(configuration: configuration, errorHandler: errorHandler)

        self.selectedModPackFile = preselectedFile
        self.isProcessingModPack = shouldStartProcessing
    }

    // MARK: - Setup Methods

    func setup(gameRepository: GameRepository) {
        self.gameRepository = gameRepository
        modPackViewModel.setGameRepository(gameRepository)

        // 如果有预选文件，启动处理
        if selectedModPackFile != nil && isProcessingModPack {
            Task {
                await parseSelectedModPack()
            }
        }

        updateParentState()
    }

    // MARK: - Override Methods
    override func performConfirmAction() async {
        startDownloadTask {
            await self.importModPack()
        }
    }

    override func handleCancel() {
        if computeIsDownloading() {
            // 停止下载任务
            downloadTask?.cancel()
            downloadTask = nil

            // 取消下载状态
            gameSetupService.downloadState.cancel()
            // ModPackInstallState没有专门的cancel方法，直接重置状态
            modPackViewModel.modPackInstallState.reset()

            // 停止处理状态
            isProcessingModPack = false
            onProcessingStateChanged(false)

            // 执行取消后的清理工作
            Task {
                await performCancelCleanup()
            }
        } else {
            configuration.actions.onCancel()
        }
    }

    override func performCancelCleanup() async {
        let gameName = gameNameValidator.gameName.trimmingCharacters(in: .whitespacesAndNewlines)
        let extractedPath = extractedModPackPath

        // 在后台执行文件删除，避免主线程 FileManager
        await Task.detached(priority: .utility) {
            let fm = FileManager.default
            if !gameName.isEmpty {
                let profileDir = AppPaths.profileDirectory(gameName: gameName)
                if fm.fileExists(atPath: profileDir.path) {
                    do {
                        try fm.removeItem(at: profileDir)
                        Logger.shared.info("已删除取消创建的ModPack游戏文件夹: \(profileDir.path)")
                    } catch {
                        Logger.shared.error("删除ModPack游戏文件夹失败: \(error.localizedDescription)")
                    }
                }
            }
            if let path = extractedPath, fm.fileExists(atPath: path.path) {
                do {
                    try fm.removeItem(at: path)
                    Logger.shared.info("已删除ModPack临时解压文件: \(path.path)")
                } catch {
                    Logger.shared.error("删除ModPack临时文件失败: \(error.localizedDescription)")
                }
            }
        }.value

        gameSetupService.downloadState.reset()
        modPackViewModel.modPackInstallState.reset()
        configuration.actions.onCancel()
    }

    override func computeIsDownloading() -> Bool {
        return gameSetupService.downloadState.isDownloading
            || modPackViewModel.modPackInstallState.isInstalling
            || isProcessingModPack
    }

    override func computeIsFormValid() -> Bool {
        let hasFile = selectedModPackFile != nil
        let hasInfo = modPackIndexInfo != nil
        let nameValid = gameNameValidator.isFormValid
        let gameVersionSupported = isGameVersionSupported
        return hasFile && hasInfo && nameValid && gameVersionSupported
    }
}
