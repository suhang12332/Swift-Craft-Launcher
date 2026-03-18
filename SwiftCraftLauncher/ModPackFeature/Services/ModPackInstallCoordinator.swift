import Foundation

@MainActor
final class ModPackInstallCoordinator {
    enum ArchiveSource {
        case remote(
            selectedVersion: ModrinthProjectDetailVersion,
            projectDetail: ModrinthProjectDetail
        )
        case localArchive(URL)
    }

    struct PreparedModPack {
        let extractedPath: URL
        let indexInfo: ModrinthIndexInfo
        let projectDetailForIcon: ModrinthProjectDetail?
    }

    struct RunInput {
        let source: ArchiveSource
        let gameName: String
        let selectedGameVersion: String
        let gameSetupService: GameSetupUtil
        let gameRepository: GameRepository
        let modPackInstallState: ModPackInstallState
        let setProcessing: (Bool) -> Void
        let setLastParsedIndexInfo: (ModrinthIndexInfo?) -> Void
        let prepared: PreparedModPack?
    }

    private let downloadService: ModPackDownloadService

    init(downloadService: ModPackDownloadService) {
        self.downloadService = downloadService
    }

    func prepare(source: ArchiveSource) async -> PreparedModPack? {
        let archivePath: URL
        let projectDetailForIcon: ModrinthProjectDetail?

        switch source {
        case let .remote(selectedVersion, projectDetail):
            guard let downloadedPath = await downloadModPackFileFromVersion(
                selectedVersion: selectedVersion,
                projectDetail: projectDetail
            ) else {
                return nil
            }
            archivePath = downloadedPath
            projectDetailForIcon = projectDetail
        case .localArchive(let localURL):
            archivePath = localURL
            projectDetailForIcon = nil
        }

        guard let extractedPath = await downloadService.extractModPack(modPackPath: archivePath) else {
            return nil
        }

        guard let indexInfo = await ModPackIndexParser.parseIndex(extractedPath: extractedPath) else {
            GlobalErrorHandler.shared.handle(
                GlobalError.resource(
                    chineseMessage: "不支持的整合包格式，请使用 Modrinth (.mrpack) 或 CurseForge (.zip) 格式的整合包",
                    i18nKey: "error.resource.unsupported_modpack_format",
                    level: .notification
                )
            )
            return nil
        }

        return .init(
            extractedPath: extractedPath,
            indexInfo: indexInfo,
            projectDetailForIcon: projectDetailForIcon
        )
    }

    func run(_ input: RunInput) async -> Bool {
        input.setProcessing(true)

        let extractedPath: URL
        let indexInfo: ModrinthIndexInfo
        let projectDetailForIcon: ModrinthProjectDetail?

        if let prepared = input.prepared {
            extractedPath = prepared.extractedPath
            indexInfo = prepared.indexInfo
            projectDetailForIcon = prepared.projectDetailForIcon
            input.setLastParsedIndexInfo(indexInfo)
        } else {
            guard let prepared = await prepare(source: input.source) else {
                input.setProcessing(false)
                return false
            }
            extractedPath = prepared.extractedPath
            indexInfo = prepared.indexInfo
            projectDetailForIcon = prepared.projectDetailForIcon
            input.setLastParsedIndexInfo(indexInfo)
        }

        // 4. 下载游戏图标（可选）
        let iconPath: String?
        if let projectDetailForIcon {
            iconPath = await downloadService.downloadGameIcon(
                projectDetail: projectDetailForIcon,
                gameName: input.gameName
            )
        } else {
            iconPath = nil
        }

        // 5. 创建 profile 文件夹
        let profileCreated = await createProfileDirectories(for: input.gameName)
        guard profileCreated else {
            await handleInstallationResult(
                success: false,
                gameName: input.gameName,
                gameSetupService: input.gameSetupService,
                modPackInstallState: input.modPackInstallState
            )
            return false
        }

        // 进入安装阶段（复制 overrides / 下载文件 / 安装依赖），不再视为“解析中”
        input.setProcessing(false)

        // 6. 复制 overrides
        let resourceDir = AppPaths.profileDirectory(gameName: input.gameName)
        let overridesTotal = await calculateOverridesTotal(extractedPath: extractedPath)
        if overridesTotal > 0 {
            input.modPackInstallState.isInstalling = true
            input.modPackInstallState.overridesTotal = overridesTotal
            input.modPackInstallState.objectWillChange.send()
        }

        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒

        let overridesSuccess = await ModPackDependencyInstaller.installOverrides(
            extractedPath: extractedPath,
            resourceDir: resourceDir
        ) { fileName, completed, total, type in
            Task { @MainActor in
                self.updateInstallProgress(
                    modPackInstallState: input.modPackInstallState,
                    fileName: fileName,
                    completed: completed,
                    total: total,
                    type: type
                )
                input.modPackInstallState.objectWillChange.send()
            }
        }

        guard overridesSuccess else {
            await handleInstallationResult(
                success: false,
                gameName: input.gameName,
                gameSetupService: input.gameSetupService,
                modPackInstallState: input.modPackInstallState
            )
            return false
        }

        // 7. 准备安装
        let tempGameInfo = GameVersionInfo(
            id: UUID(),
            gameName: input.gameName,
            gameIcon: iconPath ?? "",
            gameVersion: input.selectedGameVersion,
            assetIndex: "",
            modLoader: indexInfo.loaderType
        )

        let (filesToDownload, requiredDependencies) = calculateInstallationCounts(from: indexInfo)
        input.modPackInstallState.startInstallation(
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
                self.updateInstallProgress(
                    modPackInstallState: input.modPackInstallState,
                    fileName: fileName,
                    completed: completed,
                    total: total,
                    type: type
                )
                input.modPackInstallState.objectWillChange.send()
            }
        }

        guard filesSuccess else {
            await handleInstallationResult(
                success: false,
                gameName: input.gameName,
                gameSetupService: input.gameSetupService,
                modPackInstallState: input.modPackInstallState
            )
            return false
        }

        // 9. 安装依赖
        let dependencySuccess = await ModPackDependencyInstaller.installModPackDependencies(
            dependencies: indexInfo.dependencies,
            gameInfo: tempGameInfo,
            resourceDir: resourceDir
        ) { fileName, completed, total, type in
            Task { @MainActor in
                self.updateInstallProgress(
                    modPackInstallState: input.modPackInstallState,
                    fileName: fileName,
                    completed: completed,
                    total: total,
                    type: type
                )
                input.modPackInstallState.objectWillChange.send()
            }
        }

        guard dependencySuccess else {
            await handleInstallationResult(
                success: false,
                gameName: input.gameName,
                gameSetupService: input.gameSetupService,
                modPackInstallState: input.modPackInstallState
            )
            return false
        }

        // 10. 安装游戏本体
        let gameSuccess = await withCheckedContinuation { continuation in
            Task {
                await input.gameSetupService.saveGame(
                    gameName: input.gameName,
                    gameIcon: iconPath ?? "",
                    selectedGameVersion: input.selectedGameVersion,
                    selectedModLoader: indexInfo.loaderType,
                    specifiedLoaderVersion: indexInfo.loaderVersion,
                    pendingIconData: nil,
                    playerListViewModel: nil,
                    gameRepository: input.gameRepository,
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

        await handleInstallationResult(
            success: gameSuccess,
            gameName: input.gameName,
            gameSetupService: input.gameSetupService,
            modPackInstallState: input.modPackInstallState
        )

        downloadService.cleanupTempFiles()
        return gameSuccess
    }

    // MARK: - Helpers

    private func downloadModPackFileFromVersion(
        selectedVersion: ModrinthProjectDetailVersion,
        projectDetail: ModrinthProjectDetail
    ) async -> URL? {
        let primaryFile =
            selectedVersion.files.first { $0.primary }
            ?? selectedVersion.files.first

        guard let fileToDownload = primaryFile else {
            GlobalErrorHandler.shared.handle(
                GlobalError.resource(
                    chineseMessage: "没有找到可下载的文件",
                    i18nKey: "error.resource.no_downloadable_file",
                    level: .notification
                )
            )
            return nil
        }

        return await downloadService.downloadModPackFile(file: fileToDownload, projectDetail: projectDetail)
    }

    private func calculateOverridesTotal(extractedPath: URL) async -> Int {
        var overridesPath = extractedPath.appendingPathComponent("overrides")
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

        guard FileManager.default.fileExists(atPath: overridesPath.path) else {
            return 0
        }

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
        modPackInstallState: ModPackInstallState,
        fileName: String,
        completed: Int,
        total: Int,
        type: ModPackDependencyInstaller.DownloadType
    ) {
        switch type {
        case .files:
            modPackInstallState.updateFilesProgress(
                fileName: fileName,
                completed: completed,
                total: total
            )
        case .dependencies:
            modPackInstallState.updateDependenciesProgress(
                dependencyName: fileName,
                completed: completed,
                total: total
            )
        case .overrides:
            modPackInstallState.updateOverridesProgress(
                overrideName: fileName,
                completed: completed,
                total: total
            )
        }
    }

    private func handleInstallationResult(
        success: Bool,
        gameName: String,
        gameSetupService: GameSetupUtil,
        modPackInstallState: ModPackInstallState
    ) async {
        if success {
            Logger.shared.info("整合包依赖安装完成: \(gameName)")
        } else {
            Logger.shared.error("整合包依赖安装失败: \(gameName)")
            await cleanupGameDirectories(gameName: gameName)
            GlobalErrorHandler.shared.handle(
                GlobalError.resource(
                    chineseMessage: "整合包依赖安装失败",
                    i18nKey: "error.resource.modpack_dependencies_failed",
                    level: .notification
                )
            )
            modPackInstallState.reset()
            gameSetupService.downloadState.reset()
        }
    }

    private func cleanupGameDirectories(gameName: String) async {
        do {
            let fileManager = MinecraftFileManager()
            try fileManager.cleanupGameDirectories(gameName: gameName)
        } catch {
            Logger.shared.error("清理游戏文件夹失败: \(error.localizedDescription)")
        }
    }
}
