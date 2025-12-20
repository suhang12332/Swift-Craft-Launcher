import SwiftUI

// MARK: - 主资源添加 Sheet
struct GlobalResourceSheet: View {
    let project: ModrinthProject
    let resourceType: String
    @Binding var isPresented: Bool
    @EnvironmentObject var gameRepository: GameRepository
    @State private var selectedGame: GameVersionInfo?
    @State private var selectedVersion: ModrinthProjectDetailVersion?
    @State private var availableVersions: [ModrinthProjectDetailVersion] = []
    @State private var projectDetail: ModrinthProjectDetail?
    @State private var isLoading = true
    @State private var error: GlobalError?
    @State private var dependencyState = DependencyState()
    @State private var hasLoadedDetail = false
    @State private var isDownloadingAll = false
    @State private var isDownloadingMainOnly = false
    @State private var mainVersionId = ""

    var body: some View {
        CommonSheetView(
            header: {
                Text(
                    selectedGame.map {
                        String(
                            format: "global_resource.add_for_game".localized(),
                            $0.gameName
                        )
                    } ?? "global_resource.add".localized()
                )
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            },
            body: {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else if let error = error {
                    newErrorView(error)
                } else if let detail = projectDetail {
                    let compatibleGames = filterCompatibleGames(
                        detail: detail,
                        gameRepository: gameRepository,
                        resourceType: resourceType,
                        projectId: project.projectId
                    )
                    if compatibleGames.isEmpty {
                        Text("global_resource.no_game_list".localized())
                            .foregroundColor(.secondary).padding()
                    } else {
                        VStack {
                            ModrinthProjectTitleView(
                                projectDetail: detail
                            ).padding(.bottom, 18)
                            CommonSheetGameBody(
                                compatibleGames: compatibleGames,
                                selectedGame: $selectedGame
                            )
                            if let game = selectedGame {
                                spacerView()
                                VersionPickerForSheet(
                                    project: project,
                                    resourceType: resourceType,
                                    selectedGame: $selectedGame,
                                    selectedVersion: $selectedVersion,
                                    availableVersions: $availableVersions,
                                    mainVersionId: $mainVersionId
                                ) { version in
                                    if resourceType == "mod",
                                        let v = version {
                                        loadDependencies(for: v, game: game)
                                    } else {
                                        dependencyState = DependencyState()
                                    }
                                }
                                if resourceType == "mod" && !GameSettingsManager.shared.autoDownloadDependencies {
                                    spacerView()
                                    DependencySectionView(state: $dependencyState)
                                }
                            }
                        }
                    }
                }
            },
            footer: {
                GlobalResourceFooter(
                    project: project,
                    resourceType: resourceType,
                    isPresented: $isPresented,
                    projectDetail: projectDetail,
                    selectedGame: selectedGame,
                    selectedVersion: selectedVersion,
                    dependencyState: dependencyState,
                    isDownloadingAll: $isDownloadingAll,
                    isDownloadingMainOnly: $isDownloadingMainOnly,
                    gameRepository: gameRepository,
                    loadDependencies: loadDependencies,
                    mainVersionId: $mainVersionId
                )
            }
        )
        .onAppear {
            if !hasLoadedDetail {
                hasLoadedDetail = true
                loadDetail()
            }
        }
    }

    private func loadDetail() {
        isLoading = true
        error = nil
        Task {
            do {
                try await loadDetailThrowing()
            } catch {
                let globalError = GlobalError.from(error)
                _ = await MainActor.run {
                    self.error = globalError
                    self.isLoading = false
                }
            }
        }
    }

    private func loadDetailThrowing() async throws {
        guard !project.projectId.isEmpty else {
            throw GlobalError.validation(
                chineseMessage: "项目ID不能为空",
                i18nKey: "error.validation.project_id_empty",
                level: .notification
            )
        }

        guard
            let detail = await ModrinthService.fetchProjectDetails(
                id: project.projectId
            )
        else {
            throw GlobalError.resource(
                chineseMessage: "无法获取项目详情",
                i18nKey: "error.resource.project_details_not_found",
                level: .notification
            )
        }

        _ = await MainActor.run {
            self.projectDetail = detail
            self.isLoading = false
        }
    }

    private func loadDependencies(
        for version: ModrinthProjectDetailVersion,
        game: GameVersionInfo
    ) {
        dependencyState.isLoading = true
        Task {
            do {
                try await loadDependenciesThrowing(for: version, game: game)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("加载依赖项失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
                _ = await MainActor.run {
                    dependencyState = DependencyState()
                }
            }
        }
    }

    private func loadDependenciesThrowing(
        for version: ModrinthProjectDetailVersion,
        game: GameVersionInfo
    ) async throws {
        guard !project.projectId.isEmpty else {
            throw GlobalError.validation(
                chineseMessage: "项目ID不能为空",
                i18nKey: "error.validation.project_id_empty",
                level: .notification
            )
        }

        // 获取缺失的依赖项（包含版本信息）
        let missingWithVersions =
            await ModrinthDependencyDownloader
            .getMissingDependenciesWithVersions(
                for: project.projectId,
                gameInfo: game
            )

        var depVersions: [String: [ModrinthProjectDetailVersion]] = [:]
        var depSelected: [String: ModrinthProjectDetailVersion?] = [:]
        var dependencies: [ModrinthProjectDetail] = []

        for (detail, versions) in missingWithVersions {
            dependencies.append(detail)
            depVersions[detail.id] = versions
            depSelected[detail.id] = versions.first
        }

        _ = await MainActor.run {
            dependencyState = DependencyState(
                dependencies: dependencies,
                versions: depVersions,
                selected: depSelected,
                isLoading: false
            )
        }
    }
}
