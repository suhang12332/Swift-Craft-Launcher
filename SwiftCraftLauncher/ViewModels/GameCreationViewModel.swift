//
//  GameCreationViewModel.swift
//  SwiftCraftLauncher
//
//  Created by AI Assistant on 2025/1/27.
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
    @Published var selectedModLoader = "vanilla"
    @Published var selectedLoaderVersion = ""
    @Published var availableLoaderVersions: [String] = []
    @Published var availableVersions: [String] = []

    // MARK: - Private Properties
    private var pendingIconData: Data?
    private var pendingIconURL: URL?
    private var didInit = false

    // MARK: - Environment Objects (to be set from view)
    private var gameRepository: GameRepository?
    private var playerListViewModel: PlayerListViewModel?

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
        let isLoaderVersionValid = selectedModLoader == "vanilla" || !selectedLoaderVersion.isEmpty
        return gameNameValidator.isFormValid && isLoaderVersionValid
    }

    // MARK: - Version Management
    /// 初始化版本选择器
    func initializeVersionPicker() async {
        let compatibleVersions = await CommonService.compatibleVersions(for: selectedModLoader)
        await updateAvailableVersions(compatibleVersions)
    }

    /// 更新可用版本并设置默认选择
    func updateAvailableVersions(_ versions: [String]) async {
        self.availableVersions = versions
        // 如果当前选中的版本不在兼容版本列表中，选择第一个兼容版本
        if !versions.contains(self.selectedGameVersion) && !versions.isEmpty {
            self.selectedGameVersion = versions.first ?? ""
        }

        // 获取当前选中版本的时间信息
        if !versions.isEmpty {
            let targetVersion = versions.contains(self.selectedGameVersion) ? self.selectedGameVersion : (versions.first ?? "")
            let timeString = await ModrinthService.queryVersionTime(from: targetVersion)
            self.versionTime = timeString
        }
    }

    /// 处理模组加载器变化
    func handleModLoaderChange(_ newLoader: String) {
        Task {
            let compatibleVersions = await CommonService.compatibleVersions(for: newLoader)
            await updateAvailableVersions(compatibleVersions)

            // 更新加载器版本列表
            if newLoader != "vanilla" && !selectedGameVersion.isEmpty {
                await updateLoaderVersions(for: newLoader, gameVersion: selectedGameVersion)
            } else {
                await MainActor.run {
                    availableLoaderVersions = []
                    selectedLoaderVersion = ""
                }
            }
        }
    }

    /// 处理游戏版本变化
    func handleGameVersionChange(_ newGameVersion: String) {
        Task {
            await updateLoaderVersions(for: selectedModLoader, gameVersion: newGameVersion)
        }
    }

    /// 更新加载器版本列表
    private func updateLoaderVersions(for loader: String, gameVersion: String) async {
        guard loader != "vanilla" && !gameVersion.isEmpty else {
            availableLoaderVersions = []
            selectedLoaderVersion = ""
            return
        }

        var versions: [String] = []

        switch loader.lowercased() {
        case "fabric":
            let fabricVersions = await FabricLoaderService.fetchAllLoaderVersions(for: gameVersion)
            versions = fabricVersions.map { $0.loader.version }
        case "forge":
            do {
                let forgeVersions = try await ForgeLoaderService.fetchAllForgeVersions(for: gameVersion)
                versions = forgeVersions.loaders.map { $0.id }
            } catch {
                Logger.shared.error("获取 Forge 版本失败: \(error.localizedDescription)")
                versions = []
            }
        case "neoforge":
            do {
                let neoforgeVersions = try await NeoForgeLoaderService.fetchAllNeoForgeVersions(for: gameVersion)
                versions = neoforgeVersions.loaders.map { $0.id }
            } catch {
                Logger.shared.error("获取 NeoForge 版本失败: \(error.localizedDescription)")
                versions = []
            }
        case "quilt":
            let quiltVersions = await QuiltLoaderService.fetchAllQuiltLoaders(for: gameVersion)
            versions = quiltVersions.map { $0.loader.version }
        default:
            versions = []
        }

        availableLoaderVersions = versions
        // 如果当前选中的版本不在列表中，选择第一个版本
        if !versions.contains(selectedLoaderVersion) && !versions.isEmpty {
            selectedLoaderVersion = versions.first ?? ""
        } else if versions.isEmpty {
            selectedLoaderVersion = ""
        }
    }

    // MARK: - Image Handling
    func handleImagePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                handleNonCriticalError(
                    GlobalError.validation(
                        chineseMessage: "未选择文件",
                        i18nKey: "error.validation.no_file_selected",
                        level: .notification
                    ),
                    message: "error.image.pick.failed".localized()
                )
                return
            }
            guard url.startAccessingSecurityScopedResource() else {
                handleFileAccessError(URLError(.cannotOpenFile), context: "图片文件")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                // 使用字符串插值而非字符串拼接
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(UUID().uuidString).png")
                try data.write(to: tempURL)
                pendingIconURL = tempURL
                pendingIconData = data
                iconImage = nil
            } catch {
                handleFileReadError(error, context: "图片文件")
            }

        case .failure(let error):
            let globalError = GlobalError.from(error)
            handleNonCriticalError(
                globalError,
                message: "error.image.pick.failed".localized()
            )
        }
    }

    func handleImageDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else {
            Logger.shared.error("图片拖放失败：没有提供者")
            return false
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(
                forTypeIdentifier: UTType.image.identifier
            ) { data, error in
                if let error = error {
                    DispatchQueue.main.async {
                        let globalError = GlobalError.from(error)
                        self.handleNonCriticalError(
                            globalError,
                            message: "error.image.load.drag.failed".localized()
                        )
                    }
                    return
                }

                if let data = data {
                    DispatchQueue.main.async {
                        // 使用字符串插值而非字符串拼接
                    let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent("\(UUID().uuidString).png")
                        do {
                            try data.write(to: tempURL)
                            self.pendingIconURL = tempURL
                            self.pendingIconData = data
                            self.iconImage = nil
                        } catch {
                            self.handleFileReadError(error, context: "图片保存")
                        }
                    }
                }
            }
            return true
        }
        Logger.shared.warning("图片拖放失败：不支持的类型")
        return false
    }

    // MARK: - Game Save Methods
    private func saveGame() async {
        guard let gameRepository = gameRepository,
              let playerListViewModel = playerListViewModel else {
            Logger.shared.error("GameRepository 或 PlayerListViewModel 未设置")
            return
        }

        // 对于非vanilla加载器，如果没有选择版本，则不允许保存
        let loaderVersion = selectedModLoader == "vanilla" ? selectedModLoader : selectedLoaderVersion

        await gameSetupService.saveGame(
            gameName: gameNameValidator.gameName,
            gameIcon: gameIcon,
            selectedGameVersion: selectedGameVersion,
            selectedModLoader: selectedModLoader,
            specifiedLoaderVersion: loaderVersion,
            pendingIconData: pendingIconData,
            playerListViewModel: playerListViewModel,
            gameRepository: gameRepository,
            onSuccess: {
                Task { @MainActor in
                    self.configuration.actions.onCancel() // Use cancel to dismiss
                }
            },
            onError: { error, message in
                Task { @MainActor in
                    self.handleNonCriticalError(error, message: message)
                }
            }
        )
    }

    // MARK: - Computed Properties for UI Updates
    var shouldShowProgress: Bool {
        gameSetupService.downloadState.isDownloading
    }

    var pendingIconURLForDisplay: URL? {
        pendingIconURL
    }
}
