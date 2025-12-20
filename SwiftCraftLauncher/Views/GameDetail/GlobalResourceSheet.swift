import SwiftUI

// MARK: - 主资源添加 Sheet
struct GlobalResourceSheet: View {
    let project: ModrinthProject
    let resourceType: String
    @Binding var isPresented: Bool
    let preloadedDetail: ModrinthProjectDetail?  // 预加载的项目详情
    @EnvironmentObject var gameRepository: GameRepository
    @State private var selectedGame: GameVersionInfo?
    @State private var selectedVersion: ModrinthProjectDetailVersion?
    @State private var availableVersions: [ModrinthProjectDetailVersion] = []
    @State private var dependencyState = DependencyState()
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
                if let detail = preloadedDetail {
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
                } else {
                    Text("global_resource.loading_error".localized())
                        .foregroundColor(.secondary)
                        .padding()
                }
            },
            footer: {
                GlobalResourceFooter(
                    project: project,
                    resourceType: resourceType,
                    isPresented: $isPresented,
                    projectDetail: preloadedDetail,
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
