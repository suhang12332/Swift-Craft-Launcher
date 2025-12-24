import SwiftUI

// MARK: - Footer 按钮区块
struct GlobalResourceFooter: View {
    let project: ModrinthProject
    let resourceType: String
    @Binding var isPresented: Bool
    let projectDetail: ModrinthProjectDetail?
    let selectedGame: GameVersionInfo?
    let selectedVersion: ModrinthProjectDetailVersion?
    let dependencyState: DependencyState
    @Binding var isDownloadingAll: Bool
    @Binding var isDownloadingMainOnly: Bool
    let gameRepository: GameRepository
    let loadDependencies:
        (ModrinthProjectDetailVersion, GameVersionInfo) -> Void
    @Binding var mainVersionId: String
    let compatibleGames: [GameVersionInfo]

    var body: some View {
        Group {
            if let detail = projectDetail {
                if compatibleGames.isEmpty {
                    HStack {
                        Spacer()
                        Button("common.close".localized()) { isPresented = false }
                    }
                } else {
                    HStack {
                        Button("common.close".localized()) { isPresented = false }
                        Spacer()
                        if resourceType == "mod" {
                            if GameSettingsManager.shared.autoDownloadDependencies {
                                if selectedVersion != nil {
                                    Button(action: downloadAll) {
                                        if isDownloadingAll {
                                            ProgressView().controlSize(.small)
                                        } else {
                                            Text(
                                                "global_resource.download_all"
                                                    .localized()
                                            )
                                        }
                                    }
                                    .disabled(isDownloadingAll)
                                    .keyboardShortcut(.defaultAction)
                                }
                            } else if !dependencyState.isLoading {
                                if selectedVersion != nil {
                                    Button(action: downloadAllManual) {
                                        if isDownloadingAll {
                                            ProgressView().controlSize(.small)
                                        } else {
                                            Text(
                                                "global_resource.download_all"
                                                    .localized()
                                            )
                                        }
                                    }
                                    .disabled(isDownloadingAll)
                                    .keyboardShortcut(.defaultAction)
                                }
                            }
                        } else {
                            if selectedVersion != nil {
                                Button(action: downloadResource) {
                                    if isDownloadingAll {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Text("global_resource.download".localized())
                                    }
                                }
                                .disabled(isDownloadingAll)
                                .keyboardShortcut(.defaultAction)
                            }
                        }
                    }
                }
            } else {
                HStack {
                    Spacer()
                    Button("common.close".localized()) { isPresented = false }
                }
            }
        }
    }

    private func downloadAll() {
        guard let game = selectedGame, selectedVersion != nil else { return }
        isDownloadingAll = true
        Task {
            do {
                try await downloadAllThrowing(game: game)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("下载所有依赖项失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
            }
            _ = await MainActor.run {
                isDownloadingAll = false
                isPresented = false
            }
        }
    }

    private func downloadAllThrowing(game: GameVersionInfo) async throws {
        guard !project.projectId.isEmpty else {
            throw GlobalError.validation(
                chineseMessage: "项目ID不能为空",
                i18nKey: "error.validation.project_id_empty",
                level: .notification
            )
        }

        var actuallyDownloaded: [ModrinthProjectDetail] = []
        var visited: Set<String> = []

        await ModrinthDependencyDownloader.downloadAllDependenciesRecursive(
            for: project.projectId,
            gameInfo: game,
            query: resourceType,
            gameRepository: gameRepository,
            actuallyDownloaded: &actuallyDownloaded,
            visited: &visited
        )
    }

    private func downloadMainOnly() {
        guard let game = selectedGame, selectedVersion != nil else { return }
        isDownloadingMainOnly = true
        Task {
            do {
                try await downloadMainOnlyThrowing(game: game)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("下载主资源失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
            }
            _ = await MainActor.run {
                isDownloadingMainOnly = false
                isPresented = false
            }
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

        let success =
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

    private func downloadAllManual() {
        guard let game = selectedGame, selectedVersion != nil else { return }
        isDownloadingAll = true
        Task {
            do {
                try await downloadAllManualThrowing(game: game)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error(
                    "手动下载所有依赖项失败: \(globalError.chineseMessage)"
                )
                GlobalErrorHandler.shared.handle(globalError)
            }
            _ = await MainActor.run {
                isDownloadingAll = false
                isPresented = false
            }
        }
    }

    private func downloadAllManualThrowing(game: GameVersionInfo) async throws {
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
                selectedVersions: dependencyState.selected.compactMapValues {
                    $0?.id
                },
                dependencyVersions: dependencyState.versions,
                mainProjectId: project.projectId,
                mainProjectVersionId: mainVersionId.isEmpty
                    ? nil : mainVersionId,
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

    private func downloadResource() {
        guard let game = selectedGame, selectedVersion != nil else { return }
        isDownloadingAll = true
        Task {
            do {
                try await downloadResourceThrowing(game: game)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("下载资源失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
            }
            _ = await MainActor.run {
                isDownloadingAll = false
                isPresented = false
            }
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

        let success =
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
