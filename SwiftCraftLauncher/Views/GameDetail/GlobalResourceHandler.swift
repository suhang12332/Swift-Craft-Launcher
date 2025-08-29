import Foundation
import SwiftUI

// MARK: - 兼容游戏过滤
func filterCompatibleGames(
    detail: ModrinthProjectDetail,
    gameRepository: GameRepository,
    resourceType: String,
    projectId: String
) -> [GameVersionInfo] {
    let supportedVersions = Set(detail.gameVersions)
    let supportedLoaders = Set(detail.loaders.map { $0.lowercased() })
    return gameRepository.games.compactMap { game in
        let localLoader = game.modLoader.lowercased()
        let match: Bool = {
            switch (resourceType, localLoader) {
            case ("datapack", "vanilla"):
                return supportedVersions.contains(game.gameVersion)
                    && supportedLoaders.contains("datapack")
            case ("shader", let loader) where loader != "vanilla":
                return supportedVersions.contains(game.gameVersion)
            case ("resourcepack", "vanilla"):
                return supportedVersions.contains(game.gameVersion)
                    && supportedLoaders.contains("minecraft")
            case ("resourcepack", _):
                return supportedVersions.contains(game.gameVersion)
            default:
                return supportedVersions.contains(game.gameVersion)
                    && supportedLoaders.contains(localLoader)
            }
        }()
        guard match else { return nil }
        if let modsDir = AppPaths.modsDirectory(gameName: game.gameName),
            ModScanner.shared.isModInstalledSync(
                projectId: projectId,
                in: modsDir
            ) {
            return nil
        }
        return game
    }
}

// MARK: - 依赖相关状态
private struct DependencyState {
    var dependencies: [ModrinthProjectDetail] = []
    var versions: [String: [ModrinthProjectDetailVersion]] = [:]
    var selected: [String: ModrinthProjectDetailVersion?] = [:]
    var isLoading = false
}

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
                                    DependencySection(state: $dependencyState)
                                }
                            }
                        }
                    }
                }
            },
            footer: {
                FooterButtons(
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

// MARK: - 依赖区块
private struct DependencySection: View {
    @Binding var state: DependencyState
    var body: some View {
        if state.isLoading {
            ProgressView().controlSize(.small)
        } else if !state.dependencies.isEmpty {
            spacerView()
            VStack(alignment: .leading, spacing: 12) {
                ForEach(state.dependencies, id: \.id) { dep in
                    VStack(alignment: .leading) {
                        Text(dep.title).font(.headline).bold()
                        if let versions = state.versions[dep.id],
                            !versions.isEmpty {
                            Picker(
                                "global_resource.dependency_version".localized(),
                                selection:
                                    Binding(
                                    get: {
                                        state.selected[dep.id] ?? versions.first
                                    },
                                    set: { state.selected[dep.id] = $0 }
                                )
                            ) {
                                ForEach(versions, id: \.id) { v in
                                    Text(v.name).tag(Optional(v))
                                }
                            }
                            .pickerStyle(.menu)
                        } else {
                            Text("global_resource.no_version".localized())
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Footer 按钮区块
private struct FooterButtons: View {
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

    var body: some View {
        if let detail = projectDetail {
            let compatibleGames = filterCompatibleGames(
                detail: detail,
                gameRepository: gameRepository,
                resourceType: resourceType,
                projectId: project.projectId
            )
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

// MARK: - 游戏选择区块
struct CommonSheetGameBody: View {
    let compatibleGames: [GameVersionInfo]
    @Binding var selectedGame: GameVersionInfo?
    var body: some View {
        Picker(
            "global_resource.select_game".localized(),
            selection: $selectedGame
        ) {
            Text("global_resource.please_select_game".localized()).tag(
                GameVersionInfo?(nil)
            )
            ForEach(compatibleGames, id: \.id) { game in
                (Text("\(game.gameName)-")
                    + Text("\(game.gameVersion)-").foregroundStyle(.secondary)
                    + Text("\(game.modLoader)-")
                    + Text("\(game.modVersion)").foregroundStyle(.secondary))
                    .tag(Optional(game))
            }
        }
        .pickerStyle(.menu)
    }
}

// MARK: - 版本选择区块
struct VersionPickerForSheet: View {
    let project: ModrinthProject
    let resourceType: String
    @Binding var selectedGame: GameVersionInfo?
    @Binding var selectedVersion: ModrinthProjectDetailVersion?
    @Binding var availableVersions: [ModrinthProjectDetailVersion]
    @Binding var mainVersionId: String
    var onVersionChange: ((ModrinthProjectDetailVersion?) -> Void)?
    @State private var isLoading = false
    @State private var error: GlobalError?

    var body: some View {
        VStack(alignment: .leading) {
            if isLoading {
                ProgressView().controlSize(.small)
            } else if !availableVersions.isEmpty {
                Text(project.title).font(.headline).bold().frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                Picker(
                    "global_resource.select_version".localized(),
                    selection: $selectedVersion
                ) {
                    ForEach(availableVersions, id: \.id) { version in
                        if resourceType == "shader" {
                            let loaders = version.loaders.joined(
                                separator: ", "
                            )
                            Text("\(version.name) (\(loaders))").tag(
                                Optional(version)
                            )
                        } else {
                            Text(version.name).tag(Optional(version))
                        }
                    }
                }
                .pickerStyle(.menu)
            } else {
                Text("global_resource.no_version_available".localized())
                    .foregroundColor(.secondary)
            }
        }
        .onAppear(perform: loadVersions)
        .onChange(of: selectedGame) { loadVersions() }
        .onChange(of: selectedVersion) { _, newValue in
            // 更新主版本ID
            if let newValue = newValue {
                mainVersionId = newValue.id
            } else {
                mainVersionId = ""
            }
            onVersionChange?(newValue)
        }
    }

    private func loadVersions() {
        isLoading = true
        error = nil
        Task {
            do {
                try await loadVersionsThrowing()
            } catch {
                let globalError = GlobalError.from(error)
                _ = await MainActor.run {
                    self.error = globalError
                    self.isLoading = false
                }
            }
        }
    }

    private func loadVersionsThrowing() async throws {
        guard !project.projectId.isEmpty else {
            throw GlobalError.validation(
                chineseMessage: "项目ID不能为空",
                i18nKey: "error.validation.project_id_empty",
                level: .notification
            )
        }

        guard let game = selectedGame else {
            _ = await MainActor.run {
                availableVersions = []
                selectedVersion = nil
                mainVersionId = ""
                isLoading = false
            }
            return
        }

        // 使用服务端的过滤方法，减少客户端过滤
        let filtered = try await ModrinthService.fetchProjectVersionsFilter(
            id: project.projectId,
            selectedVersions: [game.gameVersion],
            selectedLoaders: [game.modLoader],
            type: resourceType
        )

        _ = await MainActor.run {
            availableVersions = filtered
            selectedVersion = filtered.first
            // 更新主版本ID
            if let firstVersion = filtered.first {
                mainVersionId = firstVersion.id
            } else {
                mainVersionId = ""
            }
            isLoading = false
        }
    }
}
