import Foundation
import SwiftUI

enum GameResourceHandler {
    static func updateButtonState(
        gameInfo: GameVersionInfo?,
        project: ModrinthProject,
        gameRepository: GameRepository,
        addButtonState: Binding<ModrinthDetailCardView.AddButtonState>
    ) {
        guard let gameInfo = gameInfo else { return }
        // 由于没有文件hash，我们通过扫描目录来检查项目ID是否已安装
        let modsDir = AppPaths.modsDirectory(gameName: gameInfo.gameName)
        ModScanner.shared.scanResourceDirectory(modsDir) { details in
            let installed = details.contains { $0.id == project.projectId }
            DispatchQueue.main.async {
                if installed {
                    addButtonState.wrappedValue = .installed
                } else if addButtonState.wrappedValue == .installed {
                    addButtonState.wrappedValue = .idle
                }
            }
        }
    }

    // MARK: - 文件删除

    /// 删除文件（静默版本）
    static func performDelete(fileURL: URL) {
        do {
            try performDeleteThrowing(fileURL: fileURL)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("删除文件失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
        }
    }

    /// 删除文件（抛出异常版本）
    static func performDeleteThrowing(fileURL: URL) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw GlobalError.resource(
                chineseMessage: "文件不存在: \(fileURL.lastPathComponent)",
                i18nKey: "error.resource.file_not_found",
                level: .notification
            )
        }

        // 如果是 mod 文件，删除前获取 hash 以便从缓存中移除
        var hash: String?
        var gameName: String?
        if isModsDirectory(fileURL.deletingLastPathComponent()) {
            // 从文件路径提取 gameName
            gameName = extractGameName(from: fileURL.deletingLastPathComponent())
            // 获取文件的hash
            hash = ModScanner.sha1Hash(of: fileURL)
        }

        do {
            try FileManager.default.removeItem(at: fileURL)

            // 删除成功后，如果是 mod，从缓存中移除
            if let hash = hash, let gameName = gameName {
                ModScanner.shared.removeModHash(hash, from: gameName)
            }
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage:
                    "删除文件失败: \(fileURL.lastPathComponent), 错误: \(error.localizedDescription)",
                i18nKey: "error.filesystem.file_deletion_failed",
                level: .notification
            )
        }
    }

    /// 判断目录是否是 mods 目录
    /// - Parameter dir: 目录 URL
    /// - Returns: 是否是 mods 目录
    private static func isModsDirectory(_ dir: URL) -> Bool {
        return dir.lastPathComponent.lowercased() == "mods"
    }

    /// 从 mods 目录路径中提取游戏名称
    /// - Parameter modsDir: mods 目录 URL
    /// - Returns: 游戏名称，如果无法提取则返回 nil
    private static func extractGameName(from modsDir: URL) -> String? {
        // mods 目录结构：profileRootDirectory/gameName/mods
        // 所以 gameName 是 mods 目录的父目录名称
        let parentDir = modsDir.deletingLastPathComponent()
        return parentDir.lastPathComponent
    }

    // MARK: - 下载方法

    @MainActor
    static func downloadWithDependencies(
        project: ModrinthProject,
        gameInfo: GameVersionInfo?,
        query: String,
        gameRepository: GameRepository,
        updateButtonState: @escaping () -> Void
    ) async {
        do {
            try await downloadWithDependenciesThrowing(
                project: project,
                gameInfo: gameInfo,
                query: query,
                gameRepository: gameRepository
            )
            updateButtonState()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("下载依赖项失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
        }
    }

    @MainActor
    static func downloadWithDependenciesThrowing(
        project: ModrinthProject,
        gameInfo: GameVersionInfo?,
        query: String,
        gameRepository: GameRepository
    ) async throws {
        guard let gameInfo = gameInfo else {
            throw GlobalError.validation(
                chineseMessage: "游戏信息缺失",
                i18nKey: "error.validation.game_info_missing",
                level: .notification
            )
        }

        var actuallyDownloaded: [ModrinthProjectDetail] = []
        var visited: Set<String> = []

        await ModrinthDependencyDownloader.downloadAllDependenciesRecursive(
            for: project.projectId,
            gameInfo: gameInfo,
            query: query,
            gameRepository: gameRepository,
            actuallyDownloaded: &actuallyDownloaded,
            visited: &visited
        )
    }

    @MainActor
    static func downloadSingleResource(
        project: ModrinthProject,
        gameInfo: GameVersionInfo?,
        query: String,
        gameRepository: GameRepository,
        updateButtonState: @escaping () -> Void
    ) async {
        do {
            try await downloadSingleResourceThrowing(
                project: project,
                gameInfo: gameInfo,
                query: query,
                gameRepository: gameRepository
            )
            updateButtonState()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("下载单个资源失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
        }
    }

    @MainActor
    static func downloadSingleResourceThrowing(
        project: ModrinthProject,
        gameInfo: GameVersionInfo?,
        query: String,
        gameRepository: GameRepository
    ) async throws {
        guard let gameInfo = gameInfo else {
            throw GlobalError.validation(
                chineseMessage: "游戏信息缺失",
                i18nKey: "error.validation.game_info_missing",
                level: .notification
            )
        }

        _ = await ModrinthDependencyDownloader.downloadMainResourceOnly(
            mainProjectId: project.projectId,
            gameInfo: gameInfo,
            query: query,
            gameRepository: gameRepository,
            filterLoader: query != "shader"
        )
    }

    @MainActor
    static func prepareManualDependencies(
        project: ModrinthProject,
        gameInfo: GameVersionInfo?,
        depVM: DependencySheetViewModel
    ) async -> Bool {
        do {
            return try await prepareManualDependenciesThrowing(
                project: project,
                gameInfo: gameInfo,
                depVM: depVM
            )
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("准备手动依赖项失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            depVM.missingDependencies = []
            depVM.dependencyVersions = [:]
            depVM.selectedDependencyVersion = [:]
            depVM.isLoadingDependencies = false
            depVM.resetDownloadStates()
            return false
        }
    }

    @MainActor
    static func prepareManualDependenciesThrowing(
        project: ModrinthProject,
        gameInfo: GameVersionInfo?,
        depVM: DependencySheetViewModel
    ) async throws -> Bool {
        guard let gameInfo = gameInfo else {
            throw GlobalError.validation(
                chineseMessage: "游戏信息缺失",
                i18nKey: "error.validation.game_info_missing",
                level: .notification
            )
        }

        depVM.isLoadingDependencies = true

        let missing = await ModrinthDependencyDownloader.getMissingDependencies(
            for: project.projectId,
            gameInfo: gameInfo
        )

        if missing.isEmpty {
            depVM.isLoadingDependencies = false
            return false
        }

        var versionDict: [String: [ModrinthProjectDetailVersion]] = [:]
        var selectedVersionDict: [String: String] = [:]

        // 使用服务端的过滤方法，和全局资源安装逻辑一致
        // 预置游戏版本和加载器
        for dep in missing {
            do {
                // 使用和全局资源安装一样的服务端过滤方法
                let filteredVersions = try await ModrinthService.fetchProjectVersionsFilter(
                    id: dep.id,
                    selectedVersions: [gameInfo.gameVersion],
                    selectedLoaders: [gameInfo.modLoader],
                    type: "mod"
                )

                versionDict[dep.id] = filteredVersions
                // 和全局资源安装一样，自动选择第一个版本
                if let firstVersion = filteredVersions.first {
                    selectedVersionDict[dep.id] = firstVersion.id
                }
            } catch {
                // 如果某个依赖的版本获取失败，记录错误但继续处理其他依赖
                let globalError = GlobalError.from(error)
                Logger.shared.error("获取依赖 \(dep.title) 的版本失败: \(globalError.chineseMessage)")
                // 设置空版本列表，让用户知道这个依赖无法安装
                versionDict[dep.id] = []
            }
        }

        depVM.missingDependencies = missing
        depVM.dependencyVersions = versionDict
        depVM.selectedDependencyVersion = selectedVersionDict
        depVM.isLoadingDependencies = false
        depVM.resetDownloadStates()
        return true
    }

    @MainActor
    static func downloadAllDependenciesAndMain(
        project: ModrinthProject,
        gameInfo: GameVersionInfo?,
        depVM: DependencySheetViewModel,
        query: String,
        gameRepository: GameRepository,
        updateButtonState: @escaping () -> Void
    ) async {
        do {
            try await downloadAllDependenciesAndMainThrowing(
                project: project,
                gameInfo: gameInfo,
                depVM: depVM,
                query: query,
                gameRepository: gameRepository
            )
            updateButtonState()
            depVM.showDependenciesSheet = false
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("下载所有依赖项失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            depVM.overallDownloadState = .failed
        }
    }

    @MainActor
    static func downloadAllDependenciesAndMainThrowing(
        project: ModrinthProject,
        gameInfo: GameVersionInfo?,
        depVM: DependencySheetViewModel,
        query: String,
        gameRepository: GameRepository
    ) async throws {
        guard let gameInfo = gameInfo else {
            throw GlobalError.validation(
                chineseMessage: "游戏信息缺失",
                i18nKey: "error.validation.game_info_missing",
                level: .notification
            )
        }

        let dependencies = depVM.missingDependencies
        let selectedVersions = depVM.selectedDependencyVersion
        let dependencyVersions = depVM.dependencyVersions

        let allSucceeded =
            await ModrinthDependencyDownloader.downloadManualDependenciesAndMain(
                dependencies: dependencies,
                selectedVersions: selectedVersions,
                dependencyVersions: dependencyVersions,
                mainProjectId: project.projectId,
                mainProjectVersionId: nil,  // 使用最新版本
                gameInfo: gameInfo,
                query: query,
                gameRepository: gameRepository,
                onDependencyDownloadStart: { depId in
                    depVM.dependencyDownloadStates[depId] = .downloading
                },
                onDependencyDownloadFinish: { depId, success in
                    depVM.dependencyDownloadStates[depId] =
                        success ? .success : .failed
                }
            )

        if !allSucceeded {
            throw GlobalError.download(
                chineseMessage: "下载依赖项失败",
                i18nKey: "error.download.dependencies_failed",
                level: .notification
            )
        }
    }

    @MainActor
    static func downloadMainResourceAfterDependencies(
        project: ModrinthProject,
        gameInfo: GameVersionInfo?,
        depVM: DependencySheetViewModel,
        query: String,
        gameRepository: GameRepository,
        updateButtonState: @escaping () -> Void
    ) async {
        do {
            try await downloadMainResourceAfterDependenciesThrowing(
                project: project,
                gameInfo: gameInfo,
                query: query,
                gameRepository: gameRepository
            )
            updateButtonState()
            depVM.showDependenciesSheet = false
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("下载主资源失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
        }
    }

    @MainActor
    static func downloadMainResourceAfterDependenciesThrowing(
        project: ModrinthProject,
        gameInfo: GameVersionInfo?,
        query: String,
        gameRepository: GameRepository
    ) async throws {
        guard let gameInfo = gameInfo else {
            throw GlobalError.validation(
                chineseMessage: "游戏信息缺失",
                i18nKey: "error.validation.game_info_missing",
                level: .notification
            )
        }

        let success =
            await ModrinthDependencyDownloader.downloadMainResourceOnly(
                mainProjectId: project.projectId,
                gameInfo: gameInfo,
                query: query,
                gameRepository: gameRepository
            )

        if !success {
            throw GlobalError.download(
                chineseMessage: "下载主资源失败",
                i18nKey: "error.download.main_resource_failed",
                level: .notification
            )
        }
    }

    @MainActor
    static func retryDownloadDependency(
        dep: ModrinthProjectDetail,
        gameInfo: GameVersionInfo?,
        depVM: DependencySheetViewModel,
        query: String,
        gameRepository: GameRepository
    ) async {
        do {
            try await retryDownloadDependencyThrowing(
                dep: dep,
                gameInfo: gameInfo,
                depVM: depVM,
                query: query,
                gameRepository: gameRepository
            )
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("重试下载依赖项失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            depVM.dependencyDownloadStates[dep.id] = .failed
        }
    }

    @MainActor
    static func retryDownloadDependencyThrowing(
        dep: ModrinthProjectDetail,
        gameInfo: GameVersionInfo?,
        depVM: DependencySheetViewModel,
        query: String,
        gameRepository: GameRepository
    ) async throws {
        guard let gameInfo = gameInfo else {
            throw GlobalError.validation(
                chineseMessage: "游戏信息缺失",
                i18nKey: "error.validation.game_info_missing",
                level: .notification
            )
        }

        guard let versionId = depVM.selectedDependencyVersion[dep.id] else {
            throw GlobalError.resource(
                chineseMessage: "缺少版本ID: \(dep.id)",
                i18nKey: "error.resource.version_id_missing",
                level: .notification
            )
        }

        guard let versions = depVM.dependencyVersions[dep.id] else {
            throw GlobalError.resource(
                chineseMessage: "缺少版本信息: \(dep.id)",
                i18nKey: "error.resource.version_info_missing",
                level: .notification
            )
        }

        guard let version = versions.first(where: { $0.id == versionId }) else {
            throw GlobalError.resource(
                chineseMessage: "找不到指定版本: \(versionId)",
                i18nKey: "error.resource.version_not_found",
                level: .notification
            )
        }

        guard
            let primaryFile = ModrinthService.filterPrimaryFiles(
                from: version.files
            )
        else {
            throw GlobalError.resource(
                chineseMessage: "找不到主文件: \(dep.id)",
                i18nKey: "error.resource.primary_file_not_found",
                level: .notification
            )
        }

        depVM.dependencyDownloadStates[dep.id] = .downloading

        do {
            let fileURL = try await DownloadManager.downloadResource(
                for: gameInfo,
                urlString: primaryFile.url,
                resourceType: dep.projectType,
                expectedSha1: primaryFile.hashes.sha1
            )

            var resourceToAdd = dep
            resourceToAdd.fileName = primaryFile.filename
            resourceToAdd.type = query

            // 如果是 mod，添加到安装缓存
            if query.lowercased() == "mod" {
                // 获取下载文件的hash
                if let hash = ModScanner.sha1Hash(of: fileURL) {
                    ModScanner.shared.addModHash(
                        hash,
                        to: gameInfo.gameName
                    )
                }
            }

            depVM.dependencyDownloadStates[dep.id] = .success
        } catch {
            throw GlobalError.download(
                chineseMessage: "下载依赖项失败: \(error.localizedDescription)",
                i18nKey: "error.download.dependency_download_failed",
                level: .notification
            )
        }
    }
}
