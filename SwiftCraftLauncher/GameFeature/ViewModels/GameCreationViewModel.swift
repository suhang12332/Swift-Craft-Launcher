//
//  GameCreationViewModel.swift
//  SwiftCraftLauncher
//
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Game Creation View Model
@MainActor
class GameCreationViewModel: BaseGameFormViewModel {
    // MARK: - Published Properties
    @Published var gameIcon = AppConstants.defaultGameIcon
    @Published var iconImage: Image?
    @Published var selectedGameVersion = ""
    @Published var versionTime = ""
    @Published var selectedModLoader = GameLoader.vanilla.displayName {
        didSet {
            updateParentState()
        }
    }
    @Published var selectedLoaderVersion = "" {
        didSet {
            updateDefaultGameName()
        }
    }
    @Published var availableLoaderVersions: [String] = []
    @Published var availableVersions: [String] = []

    // MARK: - Private Properties
    var pendingIconData: Data?
    var pendingIconURL: URL?
    var didInit = false

    // MARK: - Environment Objects (to be set from view)
    var gameRepository: GameRepository?
    var playerListViewModel: PlayerListViewModel?

    // MARK: - Initialization
    override init(configuration: GameFormConfiguration) {
        super.init(configuration: configuration)
    }

    // MARK: - Setup Methods
    func setup(gameRepository: GameRepository, playerListViewModel: PlayerListViewModel) {
        self.gameRepository = gameRepository
        self.playerListViewModel = playerListViewModel

        if !didInit {
            didInit = true
            Task {
                await initializeVersionPicker()
            }
        }
        updateParentState()
    }

    // MARK: - Override Methods
    override func performConfirmAction() async {
        startDownloadTask {
            await self.saveGame()
        }
    }

    override func handleCancel() {
        if isDownloading {
            // 停止下载任务
            downloadTask?.cancel()
            downloadTask = nil

            // 取消下载状态
            gameSetupService.downloadState.cancel()

            // 执行取消后的清理工作
            Task {
                await performCancelCleanup()
            }
        } else {
            configuration.actions.onCancel()
        }
    }

    override func performCancelCleanup() async {
        // 如果正在下载时取消，需要删除已创建的游戏文件夹
        let gameName = gameNameValidator.gameName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !gameName.isEmpty {
            // 检查游戏是否已经保存到仓库中
            // 如果已经保存，说明游戏创建成功，不应该删除文件夹
            let isGameSaved = await MainActor.run {
                guard let gameRepository = gameRepository else { return false }
                return gameRepository.games.contains { $0.gameName == gameName }
            }

            if !isGameSaved {
                // 游戏未保存，说明是取消操作，可以安全删除文件夹
                do {
                    let profileDir = AppPaths.profileDirectory(gameName: gameName)

                    // 检查目录是否存在
                    if FileManager.default.fileExists(atPath: profileDir.path) {
                        try FileManager.default.removeItem(at: profileDir)
                        Logger.shared.info("已删除取消创建的游戏文件夹: \(profileDir.path)")
                    }
                } catch {
                    Logger.shared.error("删除游戏文件夹失败: \(error.localizedDescription)")
                    // 即使删除失败，也不应该阻止关闭窗口
                }
            } else {
                // 游戏已保存，不应该删除文件夹
                Logger.shared.info("游戏已成功保存，跳过删除文件夹: \(gameName)")
            }
        }

        // 重置下载状态并关闭窗口
        await MainActor.run {
            gameSetupService.downloadState.reset()
            configuration.actions.onCancel()
        }
    }

    override func computeIsDownloading() -> Bool {
        return gameSetupService.downloadState.isDownloading
    }

    override func computeIsFormValid() -> Bool {
        let isLoaderVersionValid = selectedModLoader == GameLoader.vanilla.displayName || !selectedLoaderVersion.isEmpty
        return gameNameValidator.isFormValid && isLoaderVersionValid
    }

    var shouldShowProgress: Bool {
        gameSetupService.downloadState.isDownloading
    }

    var pendingIconURLForDisplay: URL? {
        pendingIconURL
    }

    /// 添加游戏窗口关闭时，清理已加载的版本列表
    func clearLoadedVersionsOnClose() {
        availableVersions = []
        availableLoaderVersions = []
        selectedGameVersion = ""
        selectedLoaderVersion = ""
        versionTime = ""
        didInit = false
    }
}
