//
//  ModPackImportViewModel.swift
//  SwiftCraftLauncher
//
//

import SwiftUI

// MARK: - ModPack Import View Model
@MainActor
class ModPackImportViewModel: BaseGameFormViewModel {
    private let modPackViewModel = ModPackDownloadSheetViewModel()

    @Published var selectedModPackFile: URL?
    @Published var extractedModPackPath: URL?
    @Published var modPackIndexInfo: ModrinthIndexInfo?
    @Published var isProcessingModPack = false

    private let onProcessingStateChanged: (Bool) -> Void
    private var gameRepository: GameRepository?

    // MARK: - Initialization
    init(
        configuration: GameFormConfiguration,
        preselectedFile: URL? = nil,
        shouldStartProcessing: Bool = false,
        onProcessingStateChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.onProcessingStateChanged = onProcessingStateChanged
        super.init(configuration: configuration)

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
        // 如果正在下载时取消，需要删除已创建的游戏文件夹和临时文件
        let gameName = gameNameValidator.gameName.trimmingCharacters(in: .whitespacesAndNewlines)

        if !gameName.isEmpty {
            do {
                let profileDir = AppPaths.profileDirectory(gameName: gameName)

                // 检查目录是否存在
                if FileManager.default.fileExists(atPath: profileDir.path) {
                    try FileManager.default.removeItem(at: profileDir)
                    Logger.shared.info("已删除取消创建的ModPack游戏文件夹: \(profileDir.path)")
                }
            } catch {
                Logger.shared.error("删除ModPack游戏文件夹失败: \(error.localizedDescription)")
                // 即使删除失败，也不应该阻止关闭窗口
            }
        }

        // 清理解压的临时文件
        if let extractedPath = extractedModPackPath {
            do {
                if FileManager.default.fileExists(atPath: extractedPath.path) {
                    try FileManager.default.removeItem(at: extractedPath)
                    Logger.shared.info("已删除ModPack临时解压文件: \(extractedPath.path)")
                }
            } catch {
                Logger.shared.error("删除ModPack临时文件失败: \(error.localizedDescription)")
            }
        }

        // 重置下载状态并关闭窗口
        await MainActor.run {
            gameSetupService.downloadState.reset()
            modPackViewModel.modPackInstallState.reset()
            configuration.actions.onCancel()
        }
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
        return hasFile && hasInfo && nameValid
    }

    // MARK: - ModPack Processing
    func parseSelectedModPack() async {
        guard let selectedFile = selectedModPackFile else { return }

        isProcessingModPack = true
        onProcessingStateChanged(true)

        // 解压整合包
        guard let extracted = await modPackViewModel.extractModPack(modPackPath: selectedFile) else {
            isProcessingModPack = false
            onProcessingStateChanged(false)
            return
        }

        extractedModPackPath = extracted

        // 解析索引信息
        if let parsed = await modPackViewModel.parseModrinthIndex(extractedPath: extracted) {
            modPackIndexInfo = parsed
            let defaultName = GameNameGenerator.generateImportName(
                modPackName: parsed.modPackName,
                modPackVersion: parsed.modPackVersion,
                includeTimestamp: true
            )
            gameNameValidator.setDefaultName(defaultName)
            isProcessingModPack = false
            onProcessingStateChanged(false)
        } else {
            isProcessingModPack = false
            onProcessingStateChanged(false)
        }
    }

    // MARK: - ModPack Import
    private func importModPack() async {
        guard selectedModPackFile != nil,
              let extractedPath = extractedModPackPath,
              let indexInfo = modPackIndexInfo,
              let gameRepository = gameRepository else { return }

        isProcessingModPack = true

        // 1. 创建 profile 文件夹
        let profileCreated = await createProfileDirectories(for: gameNameValidator.gameName)

        if !profileCreated {
            handleModPackInstallationResult(success: false, gameName: gameNameValidator.gameName)
            return
        }

        // 2. 复制 overrides 文件（在安装依赖之前）
        let resourceDir = AppPaths.profileDirectory(gameName: gameNameValidator.gameName)
        // 先计算 overrides 文件总数
        let overridesTotal = await calculateOverridesTotal(extractedPath: extractedPath)

        // 只有当有 overrides 文件时，才提前设置 isInstalling 和 overridesTotal
        // 确保进度条能在复制开始前显示（updateOverridesProgress 会在回调中更新其他状态）
        if overridesTotal > 0 {
            await MainActor.run {
                modPackViewModel.modPackInstallState.isInstalling = true
                modPackViewModel.modPackInstallState.overridesTotal = overridesTotal
                modPackViewModel.objectWillChange.send()
            }
        }

        // 等待一小段时间，确保 UI 更新
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒

        let overridesSuccess = await ModPackDependencyInstaller.installOverrides(
            extractedPath: extractedPath,
            resourceDir: resourceDir
        ) { [self] fileName, completed, total, type in
            Task { @MainActor in
                updateModPackInstallProgress(
                    fileName: fileName,
                    completed: completed,
                    total: total,
                    type: type
                )
                modPackViewModel.objectWillChange.send()
            }
        }

        if !overridesSuccess {
            handleModPackInstallationResult(success: false, gameName: gameNameValidator.gameName)
            return
        }

        // 3. 准备安装
        let tempGameInfo = GameVersionInfo(
            id: UUID(),
            gameName: gameNameValidator.gameName,
            gameIcon: AppConstants.defaultGameIcon,
            gameVersion: indexInfo.gameVersion,
            assetIndex: "",
            modLoader: indexInfo.loaderType
        )

        let (filesToDownload, requiredDependencies) = calculateInstallationCounts(from: indexInfo)

        modPackViewModel.modPackInstallState.startInstallation(
            filesTotal: filesToDownload.count,
            dependenciesTotal: requiredDependencies.count
        )

        isProcessingModPack = false

        // 4. 下载整合包文件（mod 文件）
        let filesSuccess = await ModPackDependencyInstaller.installModPackFiles(
            files: indexInfo.files,
            resourceDir: resourceDir,
            gameInfo: tempGameInfo
        ) { [self] fileName, completed, total, type in
            Task { @MainActor in
                modPackViewModel.objectWillChange.send()
                updateModPackInstallProgress(
                    fileName: fileName,
                    completed: completed,
                    total: total,
                    type: type
                )
            }
        }

        if !filesSuccess {
            handleModPackInstallationResult(success: false, gameName: gameNameValidator.gameName)
            return
        }

        // 5. 安装依赖
        let dependencySuccess = await ModPackDependencyInstaller.installModPackDependencies(
            dependencies: indexInfo.dependencies,
            gameInfo: tempGameInfo,
            resourceDir: resourceDir
        ) { [self] fileName, completed, total, type in
            Task { @MainActor in
                modPackViewModel.objectWillChange.send()
                updateModPackInstallProgress(
                    fileName: fileName,
                    completed: completed,
                    total: total,
                    type: type
                )
            }
        }

        if !dependencySuccess {
            handleModPackInstallationResult(success: false, gameName: gameNameValidator.gameName)
            return
        }

        // 6. 安装游戏本体
        let gameSuccess = await withCheckedContinuation { continuation in
            Task {
                await gameSetupService.saveGame(
                    gameName: gameNameValidator.gameName,
                    gameIcon: AppConstants.defaultGameIcon,
                    selectedGameVersion: indexInfo.gameVersion,
                    selectedModLoader: indexInfo.loaderType,
                    specifiedLoaderVersion: indexInfo.loaderVersion,
                    pendingIconData: nil,
                    playerListViewModel: nil, // Will be set from environment
                    gameRepository: gameRepository,
                    onSuccess: {
                        continuation.resume(returning: true)
                    },
                    onError: { error, message in
                        Task { @MainActor in
                            Logger.shared.error("游戏设置失败: \(message)")
                            GlobalErrorHandler.shared.handle(error)
                        }
                        continuation.resume(returning: false)
                    }
                )
            }
        }

        handleModPackInstallationResult(success: gameSuccess, gameName: gameNameValidator.gameName)
    }

    // MARK: - Helper Methods
    private func calculateOverridesTotal(extractedPath: URL) async -> Int {
        // 优先检查 Modrinth 格式的 overrides
        var overridesPath = extractedPath.appendingPathComponent("overrides")

        // 如果不存在，检查 CurseForge 格式的 overrides 文件夹
        if !FileManager.default.fileExists(atPath: overridesPath.path) {
            let possiblePaths = ["overrides", "Override", "override"]
            for pathName in possiblePaths {
                let testPath = extractedPath.appendingPathComponent(pathName)
                if FileManager.default.fileExists(atPath: testPath.path) {
                    overridesPath = testPath
                    break
                }
            }
        }

        // 如果 overrides 文件夹不存在，返回 0
        guard FileManager.default.fileExists(atPath: overridesPath.path) else {
            return 0
        }

        // 计算文件总数
        do {
            let allFiles = try InstanceFileCopier.getAllFiles(in: overridesPath)
            return allFiles.count
        } catch {
            Logger.shared.error("计算 overrides 文件总数失败: \(error.localizedDescription)")
            return 0
        }
    }

    private func createProfileDirectories(for gameName: String) async -> Bool {
        let profileDirectory = AppPaths.profileDirectory(gameName: gameName)

        let subdirs = AppPaths.profileSubdirectories.map {
            profileDirectory.appendingPathComponent($0)
        }

        for dir in [profileDirectory] + subdirs {
            do {
                try FileManager.default.createDirectory(
                    at: dir,
                    withIntermediateDirectories: true
                )
            } catch {
                Logger.shared.error("创建目录失败: \(dir.path), 错误: \(error.localizedDescription)")
                GlobalErrorHandler.shared.handle(
                    GlobalError.fileSystem(
                        chineseMessage: "创建目录失败: \(dir.path)",
                        i18nKey: "error.filesystem.directory_creation_failed",
                        level: .notification
                    )
                )
                return false
            }
        }

        return true
    }

    private func calculateInstallationCounts(
        from indexInfo: ModrinthIndexInfo
    ) -> ([ModrinthIndexFile], [ModrinthIndexProjectDependency]) {
        let filesToDownload = indexInfo.files.filter { file in
            if let env = file.env, let client = env.client,
                client.lowercased() == "unsupported" {
                return false
            }
            return true
        }
        let requiredDependencies = indexInfo.dependencies.filter {
            $0.dependencyType == "required"
        }

        return (filesToDownload, requiredDependencies)
    }

    private func updateModPackInstallProgress(
        fileName: String,
        completed: Int,
        total: Int,
        type: ModPackDependencyInstaller.DownloadType
    ) {
        switch type {
        case .files:
            modPackViewModel.modPackInstallState.updateFilesProgress(
                fileName: fileName,
                completed: completed,
                total: total
            )
        case .dependencies:
            modPackViewModel.modPackInstallState.updateDependenciesProgress(
                dependencyName: fileName,
                completed: completed,
                total: total
            )
        case .overrides:
            modPackViewModel.modPackInstallState.updateOverridesProgress(
                overrideName: fileName,
                completed: completed,
                total: total
            )
        }
    }

    private func handleModPackInstallationResult(success: Bool, gameName: String) {
        if success {
            Logger.shared.info("本地整合包导入完成: \(gameName)")
            // 清理不再需要的索引数据以释放内存
            modPackViewModel.clearParsedIndexInfo()
            configuration.actions.onCancel() // Use cancel to dismiss
        } else {
            Logger.shared.error("本地整合包导入失败: \(gameName)")
            // 清理已创建的游戏文件夹
            Task {
                await cleanupGameDirectories(gameName: gameName)
            }
            let globalError = GlobalError.resource(
                chineseMessage: "本地整合包导入失败",
                i18nKey: "error.resource.local_modpack_import_failed",
                level: .notification
            )
            GlobalErrorHandler.shared.handle(globalError)
            modPackViewModel.modPackInstallState.reset()
            gameSetupService.downloadState.reset()
            // 清理不再需要的索引数据以释放内存
            modPackViewModel.clearParsedIndexInfo()
        }
        isProcessingModPack = false
    }

    private func cleanupGameDirectories(gameName: String) async {
        do {
            let fileManager = MinecraftFileManager()
            try fileManager.cleanupGameDirectories(gameName: gameName)
        } catch {
            Logger.shared.error("清理游戏文件夹失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Computed Properties for UI Updates
    var shouldShowProgress: Bool {
        gameSetupService.downloadState.isDownloading
            || modPackViewModel.modPackInstallState.isInstalling
    }

    var hasSelectedModPack: Bool {
        selectedModPackFile != nil
    }

    var modPackName: String {
        modPackIndexInfo?.modPackName ?? ""
    }

    var gameVersion: String {
        modPackIndexInfo?.gameVersion ?? ""
    }

    var modPackVersion: String {
        modPackIndexInfo?.modPackVersion ?? ""
    }

    var loaderInfo: String {
        guard let indexInfo = modPackIndexInfo else { return "" }
        return indexInfo.loaderVersion.isEmpty
            ? indexInfo.loaderType
            : "\(indexInfo.loaderType)-\(indexInfo.loaderVersion)"
    }

    // MARK: - Expose Internal Objects
    var modPackViewModelForProgress: ModPackDownloadSheetViewModel {
        modPackViewModel
    }
}
