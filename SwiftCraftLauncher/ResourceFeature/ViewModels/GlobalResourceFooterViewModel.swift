import Foundation
import SwiftUI

@MainActor
final class GlobalResourceFooterViewModel: ObservableObject {
    private let project: ModrinthProject
    private let resourceType: String
    private let gameRepository: GameRepository

    private let isPresented: Binding<Bool>
    private let isDownloadingAll: Binding<Bool>
    private let isDownloadingMainOnly: Binding<Bool>

    init(
        project: ModrinthProject,
        resourceType: String,
        isPresented: Binding<Bool>,
        isDownloadingAll: Binding<Bool>,
        isDownloadingMainOnly: Binding<Bool>,
        gameRepository: GameRepository
    ) {
        self.project = project
        self.resourceType = resourceType
        self.isPresented = isPresented
        self.isDownloadingAll = isDownloadingAll
        self.isDownloadingMainOnly = isDownloadingMainOnly
        self.gameRepository = gameRepository
    }

    func downloadMainOnly(selectedGame: GameVersionInfo?) {
        guard let game = selectedGame else { return }

        isDownloadingMainOnly.wrappedValue = true
        Task {
            do {
                try await downloadMainOnlyThrowing(game: game)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("下载主资源失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
            }

            isDownloadingMainOnly.wrappedValue = false
            isPresented.wrappedValue = false
        }
    }

    func downloadAllManual(
        selectedGame: GameVersionInfo?,
        dependencyState: DependencyState,
        mainVersionId: String
    ) {
        guard let game = selectedGame else { return }

        isDownloadingAll.wrappedValue = true
        Task {
            do {
                try await downloadAllManualThrowing(
                    game: game,
                    dependencyState: dependencyState,
                    mainVersionId: mainVersionId
                )
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("手动下载所有依赖项失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
            }

            isDownloadingAll.wrappedValue = false
            isPresented.wrappedValue = false
        }
    }

    func addServerResource(
        selectedGame: GameVersionInfo?,
        projectDetail: ModrinthProjectDetail?
    ) {
        guard let game = selectedGame, let detail = projectDetail else { return }

        isDownloadingAll.wrappedValue = true
        Task {
            do {
                try await MinecraftJavaServerResourceUtils.addServerToGameIfNeeded(
                    game: game,
                    detail: detail
                )
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("添加服务器失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
            }

            isDownloadingAll.wrappedValue = false
            isPresented.wrappedValue = false
        }
    }

    func downloadResource(selectedGame: GameVersionInfo?) {
        guard let game = selectedGame else { return }

        isDownloadingAll.wrappedValue = true
        Task {
            do {
                try await downloadResourceThrowing(game: game)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("下载资源失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
            }

            isDownloadingAll.wrappedValue = false
            isPresented.wrappedValue = false
        }
    }

    private func downloadMainOnlyThrowing(game: GameVersionInfo) async throws {
        guard !project.projectId.isEmpty else {
            throw GlobalError.validation(
                chineseMessage: "项目ID不能为空",
                i18nKey: "error.validation.project_id_empty",
                level: .notification
            )
        }

        let (success, _, _) =
            await ModrinthDependencyDownloader.downloadMainResourceOnly(
                mainProjectId: project.projectId,
                gameInfo: game,
                query: resourceType,
                gameRepository: gameRepository,
                filterLoader: true
            )

        if !success {
            throw GlobalError.download(
                chineseMessage: "下载主资源失败",
                i18nKey: "error.download.main_resource_failed",
                level: .notification
            )
        }
    }

    private func downloadAllManualThrowing(
        game: GameVersionInfo,
        dependencyState: DependencyState,
        mainVersionId: String
    ) async throws {
        guard !project.projectId.isEmpty else {
            throw GlobalError.validation(
                chineseMessage: "项目ID不能为空",
                i18nKey: "error.validation.project_id_empty",
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
                gameInfo: game,
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
    }

    private func downloadResourceThrowing(game: GameVersionInfo) async throws {
        guard !project.projectId.isEmpty else {
            throw GlobalError.validation(
                chineseMessage: "项目ID不能为空",
                i18nKey: "error.validation.project_id_empty",
                level: .notification
            )
        }

        let (success, _, _) =
            await ModrinthDependencyDownloader.downloadMainResourceOnly(
                mainProjectId: project.projectId,
                gameInfo: game,
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
    }
}
