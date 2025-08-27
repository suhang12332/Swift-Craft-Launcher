import Foundation
import SwiftUI

struct GameResourceHandler {
    static func updateButtonState(
        gameInfo: GameVersionInfo?,
        project: ModrinthProject,
        gameRepository: GameRepository,
        addButtonState: Binding<ModrinthDetailCardView.AddButtonState>
    ) {
        guard let gameInfo = gameInfo,
              let modsDir = AppPaths.modsDirectory(gameName: gameInfo.gameName) else { return }
        ModScanner.shared.isModInstalled(projectId: project.projectId, in: modsDir) { installed in
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
        
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "删除文件失败: \(fileURL.lastPathComponent), 错误: \(error.localizedDescription)",
                i18nKey: "error.filesystem.file_deletion_failed",
                level: .notification
            )
        }
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
        
        for dep in missing {
            let versions = await ModrinthService.fetchProjectVersions(id: dep.id)
            
            let filteredVersions = versions.filter {
                $0.loaders.contains(gameInfo.modLoader) && $0.gameVersions.contains(gameInfo.gameVersion)
            }
            
            versionDict[dep.id] = filteredVersions
            if let first = filteredVersions.first {
                selectedVersionDict[dep.id] = first.id
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

        let allSucceeded = await ModrinthDependencyDownloader.downloadManualDependenciesAndMain(
            dependencies: dependencies,
            selectedVersions: selectedVersions,
            dependencyVersions: dependencyVersions,
            mainProjectId: project.projectId,
            mainProjectVersionId: nil, // 使用最新版本
            gameInfo: gameInfo,
            query: query,
            gameRepository: gameRepository,
            onDependencyDownloadStart: { depId in
                depVM.dependencyDownloadStates[depId] = .downloading
            },
            onDependencyDownloadFinish: { depId, success in
                depVM.dependencyDownloadStates[depId] = success ? .success : .failed
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
        
        let success = await ModrinthDependencyDownloader.downloadMainResourceOnly(
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
        
        guard let primaryFile = ModrinthService.filterPrimaryFiles(from: version.files) else {
            throw GlobalError.resource(
                chineseMessage: "找不到主文件: \(dep.id)",
                i18nKey: "error.resource.primary_file_not_found",
                level: .notification
            )
        }
        
        depVM.dependencyDownloadStates[dep.id] = .downloading
        
        do {
            _ = try await DownloadManager.downloadResource(
                for: gameInfo,
                urlString: primaryFile.url,
                resourceType: dep.projectType,
                expectedSha1: primaryFile.hashes.sha1
            )
            
            var resourceToAdd = dep
            resourceToAdd.fileName = primaryFile.filename
            resourceToAdd.type = query
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
