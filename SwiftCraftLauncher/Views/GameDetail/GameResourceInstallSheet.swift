import SwiftUI

// MARK: - 游戏资源安装 Sheet（预置游戏信息，无需选择游戏）
struct GameResourceInstallSheet: View {
    let project: ModrinthProject
    let resourceType: String
    let gameInfo: GameVersionInfo  // 预置的游戏信息
    @Binding var isPresented: Bool
    let preloadedDetail: ModrinthProjectDetail?  // 预加载的项目详情
    @EnvironmentObject var gameRepository: GameRepository
    var onDownloadSuccess: (() -> Void)?  // 下载成功回调

    @State private var selectedVersion: ModrinthProjectDetailVersion?
    @State private var availableVersions: [ModrinthProjectDetailVersion] = []
    @State private var dependencyState = DependencyState()
    @State private var isDownloadingAll = false
    @State private var mainVersionId = ""

    var body: some View {
        CommonSheetView(
            header: {
                Text(
                    String(
                        format: "global_resource.add_for_game".localized(),
                        gameInfo.gameName
                    )
                )
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            },
            body: {
                if let detail = preloadedDetail {
                    VStack {
                        ModrinthProjectTitleView(
                            projectDetail: detail
                        ).padding(.bottom, 18)
                        VersionPickerForSheet(
                            project: project,
                            resourceType: resourceType,
                            selectedGame: .constant(gameInfo),  // 预置游戏信息
                            selectedVersion: $selectedVersion,
                            availableVersions: $availableVersions,
                            mainVersionId: $mainVersionId
                        ) { version in
                            if resourceType == "mod",
                                let v = version {
                                loadDependencies(for: v, game: gameInfo)
                            } else {
                                dependencyState = DependencyState()
                            }
                        }
                        if resourceType == "mod" {
                            if dependencyState.isLoading || !dependencyState.dependencies.isEmpty {
                                spacerView()
                                DependencySectionView(state: $dependencyState)
                            }
                        }
                    }
                }
            },
            footer: {
                GameResourceInstallFooter(
                    project: project,
                    resourceType: resourceType,
                    isPresented: $isPresented,
                    projectDetail: preloadedDetail,
                    gameInfo: gameInfo,
                    selectedVersion: selectedVersion,
                    dependencyState: dependencyState,
                    isDownloadingAll: $isDownloadingAll,
                    gameRepository: gameRepository,
                    loadDependencies: loadDependencies,
                    mainVersionId: $mainVersionId,
                    onDownloadSuccess: onDownloadSuccess
                )
            }
        )
        .onDisappear {
            // sheet 关闭时清理所有状态数据以释放内存
            selectedVersion = nil
            availableVersions = []
            dependencyState = DependencyState()
            isDownloadingAll = false
            mainVersionId = ""
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

// MARK: - Footer 按钮区块
struct GameResourceInstallFooter: View {
    let project: ModrinthProject
    let resourceType: String
    @Binding var isPresented: Bool
    let projectDetail: ModrinthProjectDetail?
    let gameInfo: GameVersionInfo
    let selectedVersion: ModrinthProjectDetailVersion?
    let dependencyState: DependencyState
    @Binding var isDownloadingAll: Bool
    let gameRepository: GameRepository
    let loadDependencies:
        (ModrinthProjectDetailVersion, GameVersionInfo) -> Void
    @Binding var mainVersionId: String
    var onDownloadSuccess: (() -> Void)?  // 下载成功回调

    var body: some View {
        Group {
            if projectDetail != nil {
                HStack {
                    Button("common.close".localized()) { isPresented = false }
                    Spacer()
                    if resourceType == "mod" {
                        if !dependencyState.isLoading {
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
            } else {
                HStack {
                    Spacer()
                    Button("common.close".localized()) { isPresented = false }
                }
            }
        }
    }

    private func downloadAllManual() {
        guard selectedVersion != nil else { return }
        isDownloadingAll = true
        Task {
            do {
                try await downloadAllManualThrowing()
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

    private func downloadAllManualThrowing() async throws {
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

        // 下载成功，调用回调
        _ = await MainActor.run {
            onDownloadSuccess?()
        }
    }

    private func downloadResource() {
        guard selectedVersion != nil else { return }
        isDownloadingAll = true
        Task {
            do {
                try await downloadResourceThrowing()
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

    private func downloadResourceThrowing() async throws {
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

        // 下载成功，调用回调
        _ = await MainActor.run {
            onDownloadSuccess?()
        }
    }
}
