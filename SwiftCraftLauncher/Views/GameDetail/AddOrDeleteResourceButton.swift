//
//  AddOrDeleteResourceButton.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/28.
//

import Foundation
import SwiftUI
import os

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

    @State private var activeAlert: ResourceButtonAlertType?
    @StateObject private var gameSettings = GameSettingsManager.shared
    @StateObject private var depVM = DependencySheetViewModel()
    @StateObject private var mainModVersionVM = MainModVersionSheetViewModel()  // 新增：主mod版本弹窗ViewModel
    @State private var isDownloadingAllDependencies = false
    @State private var isDownloadingMainResourceOnly = false
    @State private var isDownloadingMainMod = false  // 新增：主mod下载状态
    @State private var showGlobalResourceSheet = false
    @State private var showModPackDownloadSheet = false  // 新增：整合包下载 sheet
    @State private var preloadedDetail: ModrinthProjectDetail?  // 预加载的项目详情（通用：整合包/普通资源）
    @State private var preloadedCompatibleGames: [GameVersionInfo] = []  // 预检测的兼容游戏列表
    @State private var isLoadingProjectDetail = false  // 是否正在加载项目详情
    @State private var isDisabled: Bool = false  // 资源是否被禁用
    @State private var currentFileName: String?  // 当前文件名（跟踪重命名后的文件名）
    @State private var previousButtonState: ModrinthDetailCardView.AddButtonState?  // 保存之前的状态（用于恢复）
    @State private var hasDownloadedInSheet = false  // 标记在 sheet 中是否下载成功
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
//            Button {
//                showInFinder(mod)
//            } label: {
//                Label("sidebar.context_menu.show_in_finder".localized(), systemImage: "folder")
//            }
            // 更新按钮（仅在 local 模式且有更新时显示）
            if type == false && addButtonState == .update {
                Button(action: handleUpdateAction) {
                    Text("resource.update".localized())
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .font(.caption2)
                .controlSize(.small)
                .disabled(addButtonState == .loading)
            }
            
            // 禁用/启用按钮（仅本地资源显示）
            if type == false {
                Toggle("", isOn: Binding(
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
                    updateDisableState()
                    // 检测是否有新版本（仅在 local 模式且为 mod 类型）
                    if query.lowercased() == "mod" {
                        checkForUpdate()
                    }
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
            // 新增：主mod版本弹窗
            .sheet(
                isPresented: $mainModVersionVM.showMainModVersionSheet,
                onDismiss: {
                    // 如果下载成功，状态已经在 downloadMainModWithSelectedVersion() 中设置好了
                    // 如果只是关闭 sheet（没有下载），设置为"安装"状态
                    if !hasDownloadedInSheet {
                        addButtonState = .idle
                    }
                    // 重置下载标志
                    hasDownloadedInSheet = false
                    previousButtonState = nil  // 清除保存的状态
                    mainModVersionVM.cleanup()
                },
                content: {
                    MainModVersionSheetView(
                        viewModel: mainModVersionVM,
                        projectDetail: project.toDetail(),
                        isDownloading: $isDownloadingMainMod,
                        onDownload: {
                            await downloadMainModWithSelectedVersion()
                        }
                    )
                    .onDisappear {
                        mainModVersionVM.cleanup()
                    }
                }
            )
        }
        .alert(item: $activeAlert) { alertType in
            alertType.alert
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
        case .update:
            // 当有更新时，主按钮显示删除（更新按钮已单独显示在左边）
            AnyView(Text("common.delete".localized()))
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
    /// 处理更新按钮的点击
    @MainActor
    private func handleUpdateAction() {
        if !type {
            Task {
                await loadMainModVersionsBeforeOpeningSheet()
            }
        }
    }
    
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
                                // 没有依赖时，显示主mod版本弹窗
                                await loadMainModVersionsBeforeOpeningSheet()
                            }
                        }
                    } else {
                        // 其他类型也显示版本选择弹窗
                        await loadMainModVersionsBeforeOpeningSheet()
                    }
                }
            case .installed, .update:
                // 当有更新时，主按钮显示删除，点击后执行删除操作
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
                    // 对于非整合包资源，显示版本选择弹窗
                    if query != "modpack" {
                        await loadMainModVersionsBeforeOpeningSheet()
                    } else {
                        // 整合包仍然使用原有的逻辑
                        await loadProjectDetailBeforeOpeningSheet()
                    }
                }
            case .installed, .update:
                // 当有更新时，主按钮显示删除，点击后执行删除操作
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
            let installed = await ResourceInstallationChecker.checkInstalledStateForServerMode(
                project: project,
                resourceType: queryLowercased,
                installedHashes: scannedDetailIds,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders,
                gameInfo: gameInfo
            )
            await MainActor.run {
                addButtonState = installed ? .installed : .idle
            }
        }
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

        guard let result = await ResourceDetailLoader.loadProjectDetail(
            projectId: project.projectId,
            gameRepository: gameRepository,
            resourceType: query
        ) else {
            return
        }

        await MainActor.run {
            preloadedDetail = result.detail
            preloadedCompatibleGames = result.compatibleGames
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

        guard let detail = await ResourceDetailLoader.loadModPackDetail(
            projectId: project.projectId
        ) else {
            return
        }

        await MainActor.run {
            preloadedDetail = detail
            showModPackDownloadSheet = true
        }
    }
    
    // 新增：在打开主资源版本弹窗前加载版本信息（适用于所有资源类型）
    private func loadMainModVersionsBeforeOpeningSheet() async {
        guard let gameInfo = gameInfo else {
            return
        }
        
        // 保存当前状态，以便在 sheet 关闭时恢复
        await MainActor.run {
            previousButtonState = addButtonState
            hasDownloadedInSheet = false  // 重置下载标志
        }
        
        mainModVersionVM.isLoadingVersions = true
        var sheetOpened = false
        defer {
            Task { @MainActor in
                mainModVersionVM.isLoadingVersions = false
                // 如果 sheet 没有打开（加载失败等情况），设置为"安装"状态
                if !sheetOpened {
                    addButtonState = .idle
                    previousButtonState = nil
                }
            }
        }
        
        let versions = await ModrinthService.fetchProjectVersions(
            id: project.projectId
        )
        
        // 根据资源类型过滤版本
        // shader 类型不需要过滤 loader，其他类型需要
        let filteredVersions: [ModrinthProjectDetailVersion]
        if query.lowercased() == "shader" {
            filteredVersions = versions.filter {
                $0.gameVersions.contains(gameInfo.gameVersion)
            }
        } else {
            filteredVersions = versions.filter {
                $0.loaders.contains(gameInfo.modLoader)
                    && $0.gameVersions.contains(gameInfo.gameVersion)
            }
        }
        
        await MainActor.run {
            mainModVersionVM.availableVersions = filteredVersions
            if let first = filteredVersions.first {
                mainModVersionVM.selectedVersionId = first.id
            }
            mainModVersionVM.showMainModVersionSheet = true
            sheetOpened = true
        }
    }
    
    // 新增：检测是否有新版本（仅在 local 模式）
    private func checkForUpdate() {
        guard let gameInfo = gameInfo,
              type == false,  // 仅在 local 模式
              query.lowercased() == "mod"  // 仅对 mod 类型检测
        else {
            return
        }
        
        Task {
            let result = await ModUpdateChecker.checkForUpdate(
                project: project,
                gameInfo: gameInfo,
                resourceType: query
            )
            
            await MainActor.run {
                if result.hasUpdate {
                    addButtonState = .update
                } else {
                    addButtonState = .installed
                }
            }
        }
    }
    
    // 新增：使用选中的版本下载主资源（适用于所有资源类型）
    private func downloadMainModWithSelectedVersion() async {
        guard let gameInfo = gameInfo else {
            return
        }
        
        // 如果是 local 模式，先删除旧文件（更新场景）
        if !type {
            await deleteOldFileForUpdate()
        }
        
        isDownloadingMainMod = true
        defer {
            Task { @MainActor in
                isDownloadingMainMod = false
            }
        }
        
        // 使用选中的版本ID，如果没有选中则使用最新版本
        let versionId = mainModVersionVM.selectedVersionId
        
        // 使用 downloadManualDependenciesAndMain，传入空的依赖数组来只下载主mod
        let success = await ModrinthDependencyDownloader.downloadManualDependenciesAndMain(
            dependencies: [],  // 空依赖数组，只下载主mod
            selectedVersions: [:],
            dependencyVersions: [:],
            mainProjectId: project.projectId,
            mainProjectVersionId: versionId,  // 使用选中的版本ID
            gameInfo: gameInfo,
            query: query,
            gameRepository: gameRepository,
            onDependencyDownloadStart: { _ in },
            onDependencyDownloadFinish: { _, _ in }
        )
        
        if success {
            addToScannedDetailIds()
            await MainActor.run {
                // 标记已下载成功
                hasDownloadedInSheet = true
                // 下载完成后，根据资源类型设置状态
                if type == false && query.lowercased() == "mod" {
                    // local 模式的 mod 类型：检测是否有更新
                    // checkForUpdate() 会根据结果设置为 .installed 或 .update
                    checkForUpdate()
                } else {
                    // 其他资源类型或 server 模式：直接设置为已安装
                    addButtonState = .installed
                }
            }
        } else {
            // 下载失败，保持之前的状态
            await MainActor.run {
                hasDownloadedInSheet = false
                // 下载失败时，如果之前是 .update，保持 .update；否则设置为 .installed
                if let previousState = previousButtonState, previousState == .update {
                    addButtonState = .update
                } else {
                    addButtonState = .installed
                }
            }
        }
        
        // 下载完成后关闭弹窗
        await MainActor.run {
            mainModVersionVM.showMainModVersionSheet = false
        }
    }
    
    // 新增：更新前删除旧文件
    private func deleteOldFileForUpdate() async {
        guard let gameInfo = gameInfo,
              let resourceDir = AppPaths.resourceDirectory(
                  for: query,
                  gameName: gameInfo.gameName
              ) else {
            return
        }
        
        // 使用 currentFileName 如果存在，否则使用 project.fileName
        let fileName = currentFileName ?? project.fileName
        guard let fileName = fileName else {
            return
        }
        
        let fileURL = resourceDir.appendingPathComponent(fileName)
        
        // 如果文件存在，删除它
        if FileManager.default.fileExists(atPath: fileURL.path) {
            GameResourceHandler.performDelete(fileURL: fileURL)
        } else {
            // 也检查 .disabled 版本
            let disabledFileName = fileName + ".disabled"
            let disabledFileURL = resourceDir.appendingPathComponent(disabledFileName)
            if FileManager.default.fileExists(atPath: disabledFileURL.path) {
                GameResourceHandler.performDelete(fileURL: disabledFileURL)
            }
        }
        
        // 清空当前文件名，下载后会更新
        await MainActor.run {
            currentFileName = nil
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

    private func updateDisableState() {
        // 使用 currentFileName 如果存在，否则使用 project.fileName
        let fileName = currentFileName ?? project.fileName
        isDisabled = ResourceEnableDisableManager.isDisabled(fileName: fileName)
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

        do {
            let newFileName = try ResourceEnableDisableManager.toggleDisableState(
                fileName: fileName,
                resourceDir: resourceDir
            )
            // 更新当前文件名和禁用状态
            currentFileName = newFileName
            isDisabled = ResourceEnableDisableManager.isDisabled(fileName: newFileName)
        } catch {
            Logger.shared.error("切换资源启用状态失败: \(error.localizedDescription)")
        }
    }
}
