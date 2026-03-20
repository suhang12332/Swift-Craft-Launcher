import Foundation
import SwiftUI

@MainActor
final class GameResourceInstallSheetViewModel: ObservableObject {
    @Published var selectedVersion: ModrinthProjectDetailVersion?
    @Published var availableVersions: [ModrinthProjectDetailVersion] = []
    @Published var dependencyState = DependencyState()
    @Published var isDownloadingAll = false
    @Published var mainVersionId = ""

    let project: ModrinthProject
    let resourceType: String
    let gameInfo: GameVersionInfo
    let isUpdateMode: Bool

    private var gameRepository: GameRepository?

    init(
        project: ModrinthProject,
        resourceType: String,
        gameInfo: GameVersionInfo,
        isUpdateMode: Bool
    ) {
        self.project = project
        self.resourceType = resourceType
        self.gameInfo = gameInfo
        self.isUpdateMode = isUpdateMode
    }

    func setDependencies(gameRepository: GameRepository) {
        self.gameRepository = gameRepository
    }

    func onVersionChanged(_ version: ModrinthProjectDetailVersion?) {
        selectedVersion = version
        if resourceType == ResourceType.mod.rawValue, !isUpdateMode, let v = version {
            loadDependencies(for: v)
        } else {
            dependencyState = DependencyState()
        }
    }

    func loadDependencies(for version: ModrinthProjectDetailVersion) {
        dependencyState.isLoading = true
        Task {
            do {
                try await loadDependenciesThrowing()
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("加载依赖项失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
                dependencyState = DependencyState()
            }
        }
    }

    private func loadDependenciesThrowing() async throws {
        guard !project.projectId.isEmpty else {
            throw GlobalError.validation(
                chineseMessage: "项目ID不能为空",
                i18nKey: "error.validation.project_id_empty",
                level: .notification
            )
        }

        let missingWithVersions =
            await ModrinthDependencyDownloader.getMissingDependenciesWithVersions(
                for: project.projectId,
                gameInfo: gameInfo
            )

        var depVersions: [String: [ModrinthProjectDetailVersion]] = [:]
        var depSelected: [String: ModrinthProjectDetailVersion?] = [:]
        var dependencies: [ModrinthProjectDetail] = []

        for (detail, versions) in missingWithVersions {
            dependencies.append(detail)
            depVersions[detail.id] = versions
            depSelected[detail.id] = versions.first
        }

        dependencyState = DependencyState(
            dependencies: dependencies,
            versions: depVersions,
            selected: depSelected,
            isLoading: false
        )
    }

    func downloadAllManual(
        onSuccess: @escaping (String?, String?) -> Void,
        dismiss: @escaping () -> Void
    ) {
        guard selectedVersion != nil else { return }
        isDownloadingAll = true
        Task {
            do {
                try await downloadAllManualThrowing(onSuccess: onSuccess, dismiss: dismiss)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("手动下载所有依赖项失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
                isDownloadingAll = false
            }
        }
    }

    private func downloadAllManualThrowing(
        onSuccess: @escaping (String?, String?) -> Void,
        dismiss: @escaping () -> Void
    ) async throws {
        guard !project.projectId.isEmpty else {
            throw GlobalError.validation(
                chineseMessage: "项目ID不能为空",
                i18nKey: "error.validation.project_id_empty",
                level: .notification
            )
        }

        guard let gameRepository else {
            throw GlobalError.configuration(
                chineseMessage: "缺少 GameRepository",
                i18nKey: "error.configuration.game_repository_missing",
                level: .notification
            )
        }

        let success =
            await ModrinthDependencyDownloader.downloadManualDependenciesAndMain(
                dependencies: dependencyState.dependencies,
                selectedVersions: dependencyState.selected.compactMapValues { $0?.id },
                dependencyVersions: dependencyState.versions,
                mainProjectId: project.projectId,
                mainProjectVersionId: mainVersionId.isEmpty ? nil : mainVersionId,
                gameInfo: gameInfo,
                query: resourceType,
                gameRepository: gameRepository,
                onDependencyDownloadStart: { _ in },
                onDependencyDownloadFinish: { _, _ in }
            )

        if !success {
            throw GlobalError.download(
                chineseMessage: "手动下载依赖项失败",
                i18nKey: "error.download.manual_dependencies_failed",
                level: .notification
            )
        }

        onSuccess(nil, nil)
        isDownloadingAll = false
        dismiss()
    }

    func downloadResource(
        onSuccess: @escaping (String?, String?) -> Void,
        dismiss: @escaping () -> Void
    ) {
        guard selectedVersion != nil else { return }
        isDownloadingAll = true
        Task {
            do {
                try await downloadResourceThrowing(onSuccess: onSuccess, dismiss: dismiss)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("下载资源失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
                isDownloadingAll = false
            }
        }
    }

    private func downloadResourceThrowing(
        onSuccess: @escaping (String?, String?) -> Void,
        dismiss: @escaping () -> Void
    ) async throws {
        guard !project.projectId.isEmpty else {
            throw GlobalError.validation(
                chineseMessage: "项目ID不能为空",
                i18nKey: "error.validation.project_id_empty",
                level: .notification
            )
        }

        guard let gameRepository else {
            throw GlobalError.configuration(
                chineseMessage: "缺少 GameRepository",
                i18nKey: "error.configuration.game_repository_missing",
                level: .notification
            )
        }

        let (success, fileName, hash) =
            await ModrinthDependencyDownloader.downloadMainResourceOnly(
                mainProjectId: project.projectId,
                gameInfo: gameInfo,
                query: resourceType,
                gameRepository: gameRepository,
                filterLoader: true
            )

        if !success {
            throw GlobalError.download(
                chineseMessage: "下载资源失败",
                i18nKey: "error.download.resource_download_failed",
                level: .notification
            )
        }

        onSuccess(fileName, hash)
        isDownloadingAll = false
        dismiss()
    }

    func cleanup() {
        selectedVersion = nil
        availableVersions = []
        dependencyState = DependencyState()
        isDownloadingAll = false
        mainVersionId = ""
    }
}
