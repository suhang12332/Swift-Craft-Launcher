//
//  GlobalResourceFooterViewModel.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Manages download and installation actions for a project's resource footer.
@MainActor
final class GlobalResourceFooterViewModel: ObservableObject {
    private let project: ModrinthProject
    private let resourceType: String
    private let gameRepository: GameRepository
    private let errorHandler: GlobalErrorHandler

    private let isPresented: Binding<Bool>
    private let isDownloadingAll: Binding<Bool>
    private let isDownloadingMainOnly: Binding<Bool>

    init(
        project: ModrinthProject,
        resourceType: String,
        isPresented: Binding<Bool>,
        isDownloadingAll: Binding<Bool>,
        isDownloadingMainOnly: Binding<Bool>,
        gameRepository: GameRepository,
        errorHandler: GlobalErrorHandler = AppServices.errorHandler
    ) {
        self.project = project
        self.resourceType = resourceType
        self.isPresented = isPresented
        self.isDownloadingAll = isDownloadingAll
        self.isDownloadingMainOnly = isDownloadingMainOnly
        self.gameRepository = gameRepository
        self.errorHandler = errorHandler
    }

    /// Downloads the main resource only for the selected game.
    /// - Parameter selectedGame: The game version to download for.
    func downloadMainOnly(selectedGame: GameVersionInfo?) {
        guard let game = selectedGame else { return }

        isDownloadingMainOnly.wrappedValue = true
        Task {
            do {
                try await downloadMainOnlyThrowing(game: game)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("下载主资源失败: \(globalError.chineseMessage)")
                errorHandler.handle(globalError)
            }

            isDownloadingMainOnly.wrappedValue = false
            isPresented.wrappedValue = false
        }
    }

    /// Downloads the main resource and all manually selected dependencies.
    /// - Parameters:
    ///   - selectedGame: The game version to download for.
    ///   - dependencyState: The current dependency selection state.
    ///   - mainVersionId: The version ID of the main project.
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
                errorHandler.handle(globalError)
            }

            isDownloadingAll.wrappedValue = false
            isPresented.wrappedValue = false
        }
    }

    /// Adds the project as a Minecraft Java server resource and installs it.
    /// - Parameters:
    ///   - selectedGame: The game version to add the server to.
    ///   - projectDetail: The project detail information.
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
                errorHandler.handle(globalError)
            }

            isDownloadingAll.wrappedValue = false
            isPresented.wrappedValue = false
        }
    }

    /// Downloads the resource for the selected game version.
    /// - Parameter selectedGame: The game version to download for.
    func downloadResource(selectedGame: GameVersionInfo?) {
        guard let game = selectedGame else { return }

        isDownloadingAll.wrappedValue = true
        Task {
            do {
                try await downloadResourceThrowing(game: game)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("下载资源失败: \(globalError.chineseMessage)")
                errorHandler.handle(globalError)
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
                input: .init(
                    dependencies: dependencyState.dependencies,
                    selectedVersions: dependencyState.selected.compactMapValues { $0?.id },
                    dependencyVersions: dependencyState.versions,
                    mainProjectId: project.projectId,
                    mainProjectVersionId: mainVersionId.isEmpty ? nil : mainVersionId,
                    gameInfo: game,
                    resourceType: resourceType,
                    gameRepository: gameRepository
                ),
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
