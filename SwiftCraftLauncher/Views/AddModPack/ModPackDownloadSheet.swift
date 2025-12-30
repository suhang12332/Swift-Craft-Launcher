//
//  ModPackDownloadSheet.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/8/2.
//

import SwiftUI

struct ModPackDownloadSheet: View {
    let projectId: String
    let gameInfo: GameVersionInfo?
    let query: String
    let preloadedDetail: ModrinthProjectDetail?
    @EnvironmentObject private var gameRepository: GameRepository
    @Environment(\.dismiss)
    private var dismiss

    @StateObject private var viewModel = ModPackDownloadSheetViewModel()
    @State private var selectedGameVersion: String = ""
    @State private var selectedModPackVersion: ModrinthProjectDetailVersion?
    @State private var downloadTask: Task<Void, Error>?
    @State private var isProcessing = false
    @StateObject private var gameSetupService = GameSetupUtil()
    @StateObject private var gameNameValidator: GameNameValidator

    // MARK: - Initializer
    init(
        projectId: String,
        gameInfo: GameVersionInfo?,
        query: String,
        preloadedDetail: ModrinthProjectDetail? = nil
    ) {
        self.projectId = projectId
        self.gameInfo = gameInfo
        self.query = query
        self.preloadedDetail = preloadedDetail
        self._gameNameValidator = StateObject(wrappedValue: GameNameValidator(gameSetupService: GameSetupUtil()))
    }

    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: { bodyView },
            footer: { footerView }
        )
        .onAppear {
            viewModel.setGameRepository(gameRepository)
            if let preloadedDetail {
                viewModel.applyPreloadedDetail(preloadedDetail)
            } else {
                Task {
                    await viewModel.loadProjectDetails(projectId: projectId)
                }
            }
        }
        .onDisappear {
            // 页面关闭后清除所有数据
            clearAllData()
        }
    }

    // MARK: - 清除数据
    /// 清除页面所有数据
    private func clearAllData() {
        // 如果正在下载，取消下载任务
        if isDownloading {
            downloadTask?.cancel()
            downloadTask = nil
            isProcessing = false
            viewModel.modPackInstallState.reset()
            gameSetupService.downloadState.reset()
        }

        // 清理选中的版本
        selectedGameVersion = ""
        selectedModPackVersion = nil
        // 清理 ViewModel 数据
        viewModel.clearParsedIndexInfo()
    }

    // MARK: - View Components

    private var headerView: some View {
        HStack {
            Text("modpack.download.title".localized())
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var bodyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isProcessing {
                ProcessingView()
            } else if viewModel.isLoadingProjectDetails {
                ProgressView().controlSize(.small)
                    .frame(maxWidth: .infinity, minHeight: 130)
            } else if let projectDetail = viewModel.projectDetail {
                ModrinthProjectTitleView(projectDetail: projectDetail)
                    .padding(.bottom, 18)

                VersionSelectionView(
                    selectedGameVersion: $selectedGameVersion,
                    selectedModPackVersion: $selectedModPackVersion,
                    availableGameVersions: viewModel.availableGameVersions,
                    filteredModPackVersions: viewModel.filteredModPackVersions,
                    isLoadingModPackVersions: viewModel.isLoadingModPackVersions,
                    isProcessing: isProcessing,
                    onGameVersionChange: handleGameVersionChange,
                    onModPackVersionAppear: selectFirstModPackVersion
                )

                if !selectedGameVersion.isEmpty && selectedModPackVersion != nil {
                    gameNameInputSection
                }

                if shouldShowProgress {
                    DownloadProgressView(
                        gameSetupService: gameSetupService,
                        modPackInstallState: viewModel.modPackInstallState,
                        lastParsedIndexInfo: viewModel.lastParsedIndexInfo
                    )
                    .padding(.top, 18)
                }
            }
        }
    }

    private var footerView: some View {
        HStack {
            cancelButton
            Spacer()
            confirmButton
        }
    }

    // MARK: - Computed Properties

    private var shouldShowProgress: Bool {
        gameSetupService.downloadState.isDownloading
            || viewModel.modPackInstallState.isInstalling
    }

    private var canDownload: Bool {
        !selectedGameVersion.isEmpty && selectedModPackVersion != nil && gameNameValidator.isFormValid
    }

    private var isDownloading: Bool {
        isProcessing || gameSetupService.downloadState.isDownloading
            || viewModel.modPackInstallState.isInstalling
    }

    // MARK: - UI Components

    private var gameNameInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !selectedGameVersion.isEmpty && selectedModPackVersion != nil {
                GameNameInputView(
                    gameName: $gameNameValidator.gameName,
                    isGameNameDuplicate: $gameNameValidator.isGameNameDuplicate,
                    isDisabled: isProcessing,
                    gameSetupService: gameSetupService
                )
            }
        }
    }

    private var cancelButton: some View {
        Button(isDownloading ? "common.stop".localized() : "common.cancel".localized()) {
            handleCancel()
        }
        .keyboardShortcut(.cancelAction)
    }

    private var confirmButton: some View {
        Button {
            Task {
                await downloadModPack()
            }
        } label: {
            HStack {
                if isDownloading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("modpack.download.button".localized())
                }
            }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!canDownload || isDownloading)
    }

    // MARK: - Helper Methods

    private func handleGameVersionChange(_ newValue: String) {
        if !newValue.isEmpty {
            Task {
                await viewModel.loadModPackVersions(for: newValue)
            }
            // 设置默认游戏名称
            setDefaultGameName()
        } else {
            viewModel.filteredModPackVersions = []
        }
    }

    private func selectFirstModPackVersion() {
        if !viewModel.filteredModPackVersions.isEmpty
            && selectedModPackVersion == nil {
            selectedModPackVersion = viewModel.filteredModPackVersions[0]
            // 设置默认游戏名称
            setDefaultGameName()
        }
    }

    private func setDefaultGameName() {
        let defaultName = GameNameGenerator.generateModPackName(
            projectTitle: viewModel.projectDetail?.title,
            gameVersion: selectedGameVersion,
            includeTimestamp: true
        )
        gameNameValidator.setDefaultName(defaultName)
    }

    private func handleCancel() {
        if isDownloading {
            downloadTask?.cancel()
            downloadTask = nil
            isProcessing = false
            viewModel.modPackInstallState.reset()

            // 清理已创建的游戏文件夹
            Task {
                await cleanupGameDirectories(gameName: gameNameValidator.gameName)
            }
            // 停止后直接关闭sheet
            dismiss()
        } else {
            dismiss()
        }
    }

    // MARK: - Download Action

    @MainActor
    private func downloadModPack() async {
        guard let selectedVersion = selectedModPackVersion,
            let projectDetail = viewModel.projectDetail
        else { return }

        downloadTask = Task {
            await performModPackDownload(
                selectedVersion: selectedVersion,
                projectDetail: projectDetail
            )
        }
    }

    @MainActor
    private func performModPackDownload(
        selectedVersion: ModrinthProjectDetailVersion,
        projectDetail: ModrinthProjectDetail
    ) async {
        isProcessing = true

        // 1. 下载整合包
        guard
            let downloadedPath = await downloadModPackFile(
                selectedVersion: selectedVersion,
                projectDetail: projectDetail
            )
        else {
            isProcessing = false
            return
        }

        // 2. 解压整合包
        guard
            let extractedPath = await viewModel.extractModPack(
                modPackPath: downloadedPath
            )
        else {
            isProcessing = false
            return
        }

        // 3. 解析 modrinth.index.json
        guard
            let indexInfo = await viewModel.parseModrinthIndex(
                extractedPath: extractedPath
            )
        else {
            isProcessing = false
            return
        }

        // 4. 下载游戏图标
        let iconPath = await viewModel.downloadGameIcon(
            projectDetail: projectDetail,
            gameName: gameNameValidator.gameName
        )

        // 5. 创建 profile 文件夹
        let profileCreated = await withCheckedContinuation { continuation in
            Task {
                let result = await createProfileDirectories(for: gameNameValidator.gameName)
                continuation.resume(returning: result)
            }
        }

        if !profileCreated {
            handleInstallationResult(success: false, gameName: gameNameValidator.gameName)
            return
        }

        // 进入安装阶段（复制 overrides / 下载文件 / 安装依赖），不再视为“解析中”
        // 保持 UI 结构不变，仅通过状态切换让进度条区域可见
        isProcessing = false

        // 6. 复制 overrides 文件（在安装依赖之前）
        let resourceDir = AppPaths.profileDirectory(gameName: gameNameValidator.gameName)
        // 先计算 overrides 文件总数
        let overridesTotal = await calculateOverridesTotal(extractedPath: extractedPath)

        // 只有当有 overrides 文件时，才提前设置 isInstalling 和 overridesTotal
        // 确保进度条能在复制开始前显示（updateOverridesProgress 会在回调中更新其他状态）
        if overridesTotal > 0 {
            await MainActor.run {
                viewModel.modPackInstallState.isInstalling = true
                viewModel.modPackInstallState.overridesTotal = overridesTotal
                viewModel.objectWillChange.send()
            }
        }

        // 等待一小段时间，确保 UI 更新
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒

        let overridesSuccess = await ModPackDependencyInstaller.installOverrides(
            extractedPath: extractedPath,
            resourceDir: resourceDir
        ) { fileName, completed, total, type in
            Task { @MainActor in
                updateInstallProgress(
                    fileName: fileName,
                    completed: completed,
                    total: total,
                    type: type
                )
                viewModel.objectWillChange.send()
            }
        }

        if !overridesSuccess {
            handleInstallationResult(success: false, gameName: gameNameValidator.gameName)
            return
        }

        // 7. 准备安装
        let tempGameInfo = GameVersionInfo(
            id: UUID(),
            gameName: gameNameValidator.gameName,
            gameIcon: iconPath ?? "",
            gameVersion: selectedGameVersion,
            assetIndex: "",
            modLoader: indexInfo.loaderType
        )

        let (filesToDownload, requiredDependencies) =
            calculateInstallationCounts(from: indexInfo)

        viewModel.modPackInstallState.startInstallation(
            filesTotal: filesToDownload.count,
            dependenciesTotal: requiredDependencies.count
        )

        // 8. 下载整合包文件（mod 文件）
        let filesSuccess = await ModPackDependencyInstaller.installModPackFiles(
            files: indexInfo.files,
            resourceDir: resourceDir,
            gameInfo: tempGameInfo
        ) { fileName, completed, total, type in
            Task { @MainActor in
                viewModel.objectWillChange.send()
                updateInstallProgress(
                    fileName: fileName,
                    completed: completed,
                    total: total,
                    type: type
                )
            }
        }

        if !filesSuccess {
            handleInstallationResult(success: false, gameName: gameNameValidator.gameName)
            return
        }

        // 9. 安装依赖
        let dependencySuccess = await ModPackDependencyInstaller.installModPackDependencies(
            dependencies: indexInfo.dependencies,
            gameInfo: tempGameInfo,
            resourceDir: resourceDir
        ) { fileName, completed, total, type in
            Task { @MainActor in
                viewModel.objectWillChange.send()
                updateInstallProgress(
                    fileName: fileName,
                    completed: completed,
                    total: total,
                    type: type
                )
            }
        }

        if !dependencySuccess {
            handleInstallationResult(success: false, gameName: gameNameValidator.gameName)
            return
        }

        // 10. 安装游戏本体
        let gameSuccess = await withCheckedContinuation { continuation in
            Task {
                await gameSetupService.saveGame(
                    gameName: gameNameValidator.gameName,
                    gameIcon: iconPath ?? "",
                    selectedGameVersion: selectedGameVersion,
                    selectedModLoader: indexInfo.loaderType,
                    specifiedLoaderVersion: indexInfo.loaderVersion,
                    pendingIconData: nil,
                    playerListViewModel: nil,
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

        handleInstallationResult(success: gameSuccess, gameName: gameNameValidator.gameName)
    }

    private func downloadModPackFile(
        selectedVersion: ModrinthProjectDetailVersion,
        projectDetail: ModrinthProjectDetail
    ) async -> URL? {
        let primaryFile =
            selectedVersion.files.first { $0.primary }
            ?? selectedVersion.files.first

        guard let fileToDownload = primaryFile else {
            let globalError = GlobalError.resource(
                chineseMessage: "没有找到可下载的文件",
                i18nKey: "error.resource.no_downloadable_file",
                level: .notification
            )
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }

        return await viewModel.downloadModPackFile(
            file: fileToDownload,
            projectDetail: projectDetail
        )
    }

    private func calculateOverridesTotal(extractedPath: URL) async -> Int {
        // 首先检查 Modrinth 格式的 overrides 文件夹
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
                Logger.shared.error(
                    "创建目录失败: \(dir.path), 错误: \(error.localizedDescription)"
                )
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

    private func updateInstallProgress(
        fileName: String,
        completed: Int,
        total: Int,
        type: ModPackDependencyInstaller.DownloadType
    ) {
        switch type {
        case .files:
            viewModel.modPackInstallState.updateFilesProgress(
                fileName: fileName,
                completed: completed,
                total: total
            )
        case .dependencies:
            viewModel.modPackInstallState.updateDependenciesProgress(
                dependencyName: fileName,
                completed: completed,
                total: total
            )
        case .overrides:
            viewModel.modPackInstallState.updateOverridesProgress(
                overrideName: fileName,
                completed: completed,
                total: total
            )
        }
    }

    private func handleInstallationResult(success: Bool, gameName: String) {
        if success {
            Logger.shared.info("整合包依赖安装完成: \(gameName)")
            // 清理不再需要的索引数据以释放内存
            viewModel.clearParsedIndexInfo()
            dismiss()
        } else {
            Logger.shared.error("整合包依赖安装失败: \(gameName)")
            // 清理已创建的游戏文件夹
            Task {
                await cleanupGameDirectories(gameName: gameName)
            }
            let globalError = GlobalError.resource(
                chineseMessage: "整合包依赖安装失败",
                i18nKey: "error.resource.modpack_dependencies_failed",
                level: .notification
            )
            GlobalErrorHandler.shared.handle(globalError)
            viewModel.modPackInstallState.reset()
            gameSetupService.downloadState.reset()
            // 清理不再需要的索引数据以释放内存
            viewModel.clearParsedIndexInfo()
        }
        isProcessing = false
    }

    /// 清理游戏文件夹
    /// - Parameter gameName: 游戏名称
    private func cleanupGameDirectories(gameName: String) async {
        do {
            let fileManager = MinecraftFileManager()
            try fileManager.cleanupGameDirectories(gameName: gameName)
        } catch {
            Logger.shared.error("清理游戏文件夹失败: \(error.localizedDescription)")
            // 不抛出错误，因为这是清理操作，不应该影响主流程
        }
    }
}
