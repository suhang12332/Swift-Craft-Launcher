//
//  AddOrDeleteResourceButton.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/28.
//

import Foundation
import SwiftUI
import os

// 新增依赖管理ViewModel，持久化依赖相关状态
final class DependencySheetViewModel: ObservableObject {
    @Published var missingDependencies: [ModrinthProjectDetail] = []
    @Published var isLoadingDependencies = true
    @Published var showDependenciesSheet = false
    @Published var dependencyDownloadStates: [String: ResourceDownloadState] =
        [:]
    @Published var dependencyVersions:
        [String: [ModrinthProjectDetailVersion]] = [:]
    @Published var selectedDependencyVersion: [String: String] = [:]
    @Published var overallDownloadState: OverallDownloadState = .idle

    enum OverallDownloadState {
        case idle  // 初始状态，或全部下载成功后
        case failed  // 首次"全部下载"操作中，有任何文件失败；/
        case retrying  // 用户正在重试失败项
    }

    var allDependenciesDownloaded: Bool {
        // 当没有依赖时，也认为"所有依赖都已下载"
        if missingDependencies.isEmpty { return true }

        // 检查所有列出的依赖项是否都标记为成功
        return missingDependencies.allSatisfy {
            dependencyDownloadStates[$0.id] == .success
        }
    }

    func resetDownloadStates() {
        for dep in missingDependencies {
            dependencyDownloadStates[dep.id] = .idle
        }
        overallDownloadState = .idle
    }

    /// 清理所有数据，在 sheet 关闭时调用以释放内存
    func cleanup() {
        missingDependencies = []
        isLoadingDependencies = true
        dependencyDownloadStates = [:]
        dependencyVersions = [:]
        selectedDependencyVersion = [:]
        overallDownloadState = .idle
    }
}

// 1. 下载状态定义
enum ResourceDownloadState {
    case idle, downloading, success, failed
}

struct AddOrDeleteResourceButton: View {
    var project: ModrinthProject
    let selectedVersions: [String]
    let selectedLoaders: [String]
    let gameInfo: GameVersionInfo?
    let query: String
    let type: Bool  // false = local, true = server
    @Binding var scannedDetailIds: Set<String> // 已扫描资源的 detailId Set，用于快速查找（O(1)）
    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @State private var addButtonState: ModrinthDetailCardView.AddButtonState =
        .idle
    @State private var showDeleteAlert = false
    @State private var showNoGameAlert = false
    @State private var showPlayerAlert = false  // 新增：玩家验证 alert

    // Alert 类型枚举，用于管理不同的 alert
    enum AlertType: Identifiable {
        case noGame
        case noPlayer

        var id: Self { self }
    }

    @State private var activeAlert: AlertType?
    @StateObject private var gameSettings = GameSettingsManager.shared
    @StateObject private var depVM = DependencySheetViewModel()
    @State private var isDownloadingAllDependencies = false
    @State private var isDownloadingMainResourceOnly = false
    @State private var showGlobalResourceSheet = false
    @State private var showModPackDownloadSheet = false  // 新增：整合包下载 sheet
    @State private var preloadedDetail: ModrinthProjectDetail?  // 预加载的项目详情（通用：整合包/普通资源）
    @State private var preloadedCompatibleGames: [GameVersionInfo] = []  // 预检测的兼容游戏列表
    @State private var isLoadingProjectDetail = false  // 是否正在加载项目详情
    @State private var isDisabled: Bool = false  // 资源是否被禁用
    @State private var currentFileName: String?  // 当前文件名（跟踪重命名后的文件名）
    @Binding var selectedItem: SidebarItem
    //    @State private var addButtonState: ModrinthDetailCardView.AddButtonState = .idle
    var onResourceChanged: (() -> Void)?
    // 新增：local 区可强制指定已安装状态
    var forceInstalled: Bool
    // 保证所有 init 都有 onResourceChanged 参数（带默认值）
    init(
        project: ModrinthProject,
        selectedVersions: [String],
        selectedLoaders: [String],
        gameInfo: GameVersionInfo?,
        query: String,
        type: Bool,
        selectedItem: Binding<SidebarItem>,
        onResourceChanged: (() -> Void)? = nil,
        forceInstalled: Bool = false,
        scannedDetailIds: Binding<Set<String>> = .constant([])
    ) {
        self.project = project
        self.selectedVersions = selectedVersions
        self.selectedLoaders = selectedLoaders
        self.gameInfo = gameInfo
        self.query = query
        self.type = type
        self._selectedItem = selectedItem
        self.onResourceChanged = onResourceChanged
        self.forceInstalled = forceInstalled
        self._scannedDetailIds = scannedDetailIds
    }

    var body: some View {

        HStack(spacing: 8) {
            // 禁用/启用按钮（仅本地资源显示）
            if type == false {
                Toggle("Switch", isOn: Binding(
                    get: { !isDisabled },
                    set: { _ in toggleDisableState() }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)
            }

            // 安装/删除按钮
            Button(action: handleButtonAction) {
                buttonLabel
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)  // 或 .tint(.primary) 但一般用 accentColor 更美观
            .font(.caption2)
            .controlSize(.small)
            .disabled(
                addButtonState == .loading
                    || (addButtonState == .installed && type)
            )  // type = true (server mode) disables deletion
            .onAppear {
                if type == false {
                    // local 区直接显示为已安装
                    addButtonState = .installed
                    // 初始化当前文件名
                    if currentFileName == nil {
                        currentFileName = project.fileName
                    }
                    checkDisableState()
                } else {
                    updateButtonState()
                }
            }
            // 当已安装资源的 hash 集合发生变化时（例如安装或删除资源后重新扫描），
            // 根据最新扫描结果刷新按钮的安装状态
            .onChange(of: scannedDetailIds) { _, _ in
                if type {
                    updateButtonState()
                }
            }
            .confirmationDialog(
                "common.delete".localized(),
                isPresented: $showDeleteAlert,
                titleVisibility: .visible
            ) {
                Button("common.delete".localized(), role: .destructive) {
                    deleteFile()
                }
                .keyboardShortcut(.defaultAction)  // 这里可以绑定回车键

                Button("common.cancel".localized(), role: .cancel) {}
            } message: {
                Text(
                    String(
                        format: "resource.delete.confirm".localized(),
                        project.title
                    )
                )
            }
            .sheet(isPresented: $depVM.showDependenciesSheet) {
                DependencySheetView(
                    viewModel: depVM,
                    isDownloadingAllDependencies: $isDownloadingAllDependencies,
                    isDownloadingMainResourceOnly:
                        $isDownloadingMainResourceOnly,
                    projectDetail: project.toDetail(),
                    onDownloadAll: {
                        if depVM.overallDownloadState == .failed {
                            // 如果是失败后点击"继续"
                            await GameResourceHandler
                                .downloadMainResourceAfterDependencies(
                                    project: project,
                                    gameInfo: gameInfo,
                                    depVM: depVM,
                                    query: query,
                                    gameRepository: gameRepository
                                ) {
                                    addToScannedDetailIds()
                                    markInstalled()
                                }
                        } else {
                            // 首次点击"全部下载"
                            await GameResourceHandler
                                .downloadAllDependenciesAndMain(
                                    project: project,
                                    gameInfo: gameInfo,
                                    depVM: depVM,
                                    query: query,
                                    gameRepository: gameRepository
                                ) {
                                    addToScannedDetailIds()
                                    markInstalled()
                                }
                        }
                    },
                    onDownloadMainOnly: {
                        isDownloadingMainResourceOnly = true
                        await GameResourceHandler.downloadSingleResource(
                            project: project,
                            gameInfo: gameInfo,
                            query: query,
                            gameRepository: gameRepository
                        ) {
                            addToScannedDetailIds()
                            markInstalled()
                        }
                        isDownloadingMainResourceOnly = false
                        depVM.showDependenciesSheet = false
                    }
                )
                .onDisappear {
                    // sheet 关闭时清理 ViewModel 数据以释放内存
                    depVM.cleanup()
                }
            }
            .sheet(
                isPresented: $showGlobalResourceSheet,
                onDismiss: {
                    addButtonState = .idle
                    // sheet 关闭时清理预加载的数据
                    preloadedDetail = nil
                    preloadedCompatibleGames = []
                },
                content: {
                    GlobalResourceSheet(
                        project: project,
                        resourceType: query,
                        isPresented: $showGlobalResourceSheet,
                        preloadedDetail: preloadedDetail,
                        preloadedCompatibleGames: preloadedCompatibleGames
                    )
                    .environmentObject(gameRepository)
                    .onDisappear {
                        // sheet 关闭时清理预加载的数据
                        preloadedDetail = nil
                        preloadedCompatibleGames = []
                    }
                }
            )
            // 新增：整合包下载 sheet
            .sheet(
                isPresented: $showModPackDownloadSheet,
                onDismiss: {
                    addButtonState = .idle
                    // sheet 关闭时清理预加载的数据
                    preloadedDetail = nil
                },
                content: {
                    ModPackDownloadSheet(
                        projectId: project.projectId,
                        gameInfo: gameInfo,
                        query: query,
                        preloadedDetail: preloadedDetail
                    )
                    .environmentObject(gameRepository)
                    .onDisappear {
                        // sheet 关闭时清理预加载的数据
                        preloadedDetail = nil
                    }
                }
            )
        }
        .alert(item: $activeAlert) { alertType in
            switch alertType {
            case .noGame:
                return Alert(
                    title: Text("no_local_game.title".localized()),
                    message: Text("no_local_game.message".localized()),
                    dismissButton: .default(Text("common.confirm".localized()))
                )
            case .noPlayer:
                return Alert(
                    title: Text("sidebar.alert.no_player.title".localized()),
                    message: Text("sidebar.alert.no_player.message".localized()),
                    dismissButton: .default(Text("common.confirm".localized()))
                )
            }
        }
    }

    // MARK: - UI Components
    private var buttonLabel: some View {
        switch addButtonState {
        case .idle:
            AnyView(Text("resource.add".localized()))
        case .loading:
            AnyView(
                ProgressView()
                    .controlSize(.mini)
                    .font(.body)  // 设置字体大小
            )
        case .installed:
            AnyView(
                Text(
                    (!type
                        ? "common.delete".localized()
                        : "resource.installed".localized())
                )
            )
        }
    }

    // 根据文件名删除文件
    private func deleteFile() {
        // 检查 query 是否是有效的资源类型
        let validResourceTypes = ["mod", "datapack", "shader", "resourcepack"]
        let queryLowercased = query.lowercased()

        // 如果 query 是 modpack 或无效的资源类型，显示错误
        if queryLowercased == "modpack" || !validResourceTypes.contains(queryLowercased) {
            let globalError = GlobalError.configuration(
                chineseMessage: "无法删除文件：不支持删除此类型的资源",
                i18nKey: "error.configuration.delete_file_failed",
                level: .notification
            )
            Logger.shared.error("删除文件失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return
        }

        guard let gameInfo = gameInfo,
            let resourceDir = AppPaths.resourceDirectory(
                for: query,
                gameName: gameInfo.gameName
            )
        else {
            let globalError = GlobalError.configuration(
                chineseMessage: "无法删除文件：游戏信息或资源目录无效",
                i18nKey: "error.configuration.delete_file_failed",
                level: .notification
            )
            Logger.shared.error("删除文件失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return
        }

        // 只使用 fileName 删除
        guard let fileName = project.fileName else {
            let globalError = GlobalError.resource(
                chineseMessage: "无法删除文件：缺少文件名信息",
                i18nKey: "error.resource.file_name_missing",
                level: .notification,
            )
            Logger.shared.error("删除文件失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return
        }

        let fileURL = resourceDir.appendingPathComponent(fileName)
        GameResourceHandler.performDelete(fileURL: fileURL)
        onResourceChanged?()
    }

    // MARK: - Actions
    @MainActor
    private func handleButtonAction() {
        if case .game = selectedItem {
            switch addButtonState {
            case .idle:
                // 新增：对整合包的特殊处理
                if query == "modpack" {
                            addButtonState = .loading
                            Task {
                                await loadModPackDetailBeforeOpeningSheet()
                            }
                    return
                }

                addButtonState = .loading
                Task {
                    // 仅对 mod 类型检查依赖
                    if project.projectType == "mod" {
                        if gameSettings.autoDownloadDependencies {
                            await GameResourceHandler.downloadWithDependencies(
                                project: project,
                                gameInfo: gameInfo,
                                query: query,
                                gameRepository: gameRepository
                            ) {
                                addToScannedDetailIds()
                                markInstalled()
                            }
                        } else {
                            let hasMissingDeps =
                                await GameResourceHandler
                                .prepareManualDependencies(
                                    project: project,
                                    gameInfo: gameInfo,
                                    depVM: depVM
                                )
                            if hasMissingDeps {
                                depVM.showDependenciesSheet = true
                                addButtonState = .idle  // Reset button state for when sheet is dismissed
                            } else {
                                await GameResourceHandler.downloadSingleResource(
                                    project: project,
                                    gameInfo: gameInfo,
                                    query: query,
                                    gameRepository: gameRepository
                                ) {
                                    addToScannedDetailIds()
                                    markInstalled()
                                }
                            }
                        }
                    } else {
                        // 其他类型直接下载
                        await GameResourceHandler.downloadSingleResource(
                            project: project,
                            gameInfo: gameInfo,
                            query: query,
                            gameRepository: gameRepository
                        ) {
                            addToScannedDetailIds()
                            markInstalled()
                        }
                    }
                }
            case .installed:
                if !type {
                    showDeleteAlert = true
                }
            default:
                break
            }
        } else if case .resource = selectedItem {
            switch addButtonState {
            case .idle:
                // 当 type 是 true (server mode) 时的特殊处理
                if type {
                    // 对整合包的特殊处理：只需要判断有没有玩家
                    if query == "modpack" {
                        if playerListViewModel.currentPlayer == nil {
                            activeAlert = .noPlayer
                            return
                        }
                        addButtonState = .loading
                        Task {
                            await loadModPackDetailBeforeOpeningSheet()
                        }
                        return
                    }

                    // 其他资源：需要游戏存在才可以点击
                    if gameRepository.games.isEmpty {
                        activeAlert = .noGame
                        return
                    }
                } else {
                    // type 为 false (local mode) 时的原有逻辑
                    if query == "modpack" {
                        addButtonState = .loading
                        Task {
                            await loadModPackDetailBeforeOpeningSheet()
                        }
                        return
                    }
                }

                addButtonState = .loading
                Task {
                    // 先加载 projectDetail，然后再打开 sheet
                    await loadProjectDetailBeforeOpeningSheet()
                }
            case .installed:
                if !type {
                    showDeleteAlert = true
                }
            default:
                break
            }
        }
    }

    private func updateButtonState() {
        if type == false {
            addButtonState = .installed
            return
        }

        let validResourceTypes = ["mod", "datapack", "shader", "resourcepack"]
        let queryLowercased = query.lowercased()

        // modpack 目前不支持安装状态检测
        guard queryLowercased != "modpack",
            validResourceTypes.contains(queryLowercased)
        else {
            addButtonState = .idle
            return
        }

    // 仅当选中游戏且为服务端模式时才尝试通过 hash 判断已安装状态
    guard case .game = selectedItem else {
        addButtonState = .idle
        return
    }

    // 在检测开始前设置 loading 状态
    addButtonState = .loading

    Task {
        let installed = await checkInstalledStateForServerMode(resourceType: queryLowercased)
        await MainActor.run {
            addButtonState = installed ? .installed : .idle
        }
    }
    }

    /// 针对服务端模式的安装状态检查：获取兼容版本的文件 hash 并与已安装的 hash 比对
    private func checkInstalledStateForServerMode(resourceType: String) async -> Bool {
        // 已安装的 hash 列表（仅使用父视图传入的扫描结果，不做兜底扫描）
        let installedHashes = scannedDetailIds
        guard !installedHashes.isEmpty else { return false }

        // 构造版本/loader 过滤条件（优先使用用户选择，其次使用当前游戏信息）
        let versionFilters: [String] = {
            if !selectedVersions.isEmpty {
                return selectedVersions
            }
            if let gameInfo = gameInfo {
                return [gameInfo.gameVersion]
            }
            return []
        }()

        let loaderFilters: [String] = {
            if !selectedLoaders.isEmpty {
                return selectedLoaders.map { $0.lowercased() }
            }
            if let gameInfo = gameInfo {
                return [gameInfo.modLoader.lowercased()]
            }
            return []
        }()

        do {
            let versions = try await ModrinthService.fetchProjectVersionsFilter(
                id: project.projectId,
                selectedVersions: versionFilters,
                selectedLoaders: loaderFilters,
                type: resourceType
            )

            for version in versions {
                guard
                    let primaryFile = ModrinthService.filterPrimaryFiles(
                        from: version.files
                    )
                else { continue }

                if installedHashes.contains(primaryFile.hashes.sha1) {
                    return true
                }
            }
        } catch {
            Logger.shared.error(
                "获取项目版本以检查安装状态失败: \(error.localizedDescription)"
            )
        }

        return false
    }

    // 新增：在打开 sheet 前加载 projectDetail（普通资源）
    private func loadProjectDetailBeforeOpeningSheet() async {
        isLoadingProjectDetail = true
        defer {
            Task { @MainActor in
                isLoadingProjectDetail = false
                addButtonState = .idle
            }
        }

        guard let detail = await ModrinthService.fetchProjectDetails(
            id: project.projectId
        ) else {
            GlobalErrorHandler.shared.handle(GlobalError.resource(
                chineseMessage: "无法获取项目详情",
                i18nKey: "error.resource.project_details_not_found",
                level: .notification
            ))
            return
        }

        // 检测兼容游戏
        let compatibleGames = await filterCompatibleGames(
            detail: detail,
            gameRepository: gameRepository,
            resourceType: query,
            projectId: project.projectId
        )

        await MainActor.run {
            preloadedDetail = detail
            preloadedCompatibleGames = compatibleGames
            showGlobalResourceSheet = true
        }
    }

    // 新增：在打开整合包 sheet 前加载 projectDetail
    private func loadModPackDetailBeforeOpeningSheet() async {
        isLoadingProjectDetail = true
        defer {
            Task { @MainActor in
                isLoadingProjectDetail = false
                addButtonState = .idle
            }
        }

        guard let detail = await ModrinthService.fetchProjectDetails(
            id: project.projectId
        ) else {
            GlobalErrorHandler.shared.handle(GlobalError.resource(
                chineseMessage: "无法获取整合包项目详情",
                i18nKey: "error.resource.project_details_not_found",
                level: .notification
            ))
            return
        }

        await MainActor.run {
            preloadedDetail = detail
            showModPackDownloadSheet = true
        }
    }

    // 新增：在安装完成后更新 scannedDetailIds（使用hash）
    private func addToScannedDetailIds(hash: String? = nil) {
        // 如果有hash，使用hash；否则暂时不添加
        // 实际使用时，应该在下载完成后获取hash并调用此函数
        if let hash = hash {
            scannedDetailIds.insert(hash)
        }
    }

    /// 下载完成后直接标记为已安装，避免等待后续刷新
    @MainActor
    private func markInstalled() {
        addButtonState = .installed
    }

    private func checkDisableState() {
        // 使用 currentFileName 如果存在，否则使用 project.fileName
        let fileName = currentFileName ?? project.fileName
        isDisabled = (fileName?.hasSuffix(".disable") ?? false)
    }

    private func toggleDisableState() {
        guard let gameInfo = gameInfo,
            let resourceDir = AppPaths.resourceDirectory(
                for: query,
                gameName: gameInfo.gameName
            )
        else {
            Logger.shared.error("切换资源启用状态失败：资源目录不存在")
            return
        }

        // 使用 currentFileName 如果存在，否则使用 project.fileName
        let fileName = currentFileName ?? project.fileName
        guard let fileName = fileName else {
            Logger.shared.error("切换资源启用状态失败：缺少文件名")
            return
        }

        let fileManager = FileManager.default
        let currentURL = resourceDir.appendingPathComponent(fileName)
        let targetFileName: String

        if isDisabled {
            guard fileName.hasSuffix(".disable") else {
                Logger.shared.error("启用资源失败：文件后缀不包含 .disable")
                return
            }
            targetFileName = String(fileName.dropLast(".disable".count))
        } else {
            targetFileName = fileName + ".disable"
        }

        let targetURL = resourceDir.appendingPathComponent(targetFileName)

        do {
            try fileManager.moveItem(at: currentURL, to: targetURL)
            // 更新当前文件名和禁用状态
            currentFileName = targetFileName
            isDisabled = targetFileName.hasSuffix(".disable")
        } catch {
            Logger.shared.error("切换资源启用状态失败: \(error.localizedDescription)")
        }
    }
}
