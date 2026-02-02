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
    @State private var isUpdateButtonLoading = false  // 更新按钮的loading状态
    @State private var showDeleteAlert = false

    @State private var activeAlert: ResourceButtonAlertType?
    @State private var showGlobalResourceSheet = false
    @State private var showModPackDownloadSheet = false  // 新增：整合包下载 sheet
    @State private var showGameResourceInstallSheet = false  // 新增：游戏资源安装 sheet
    @State private var preloadedDetail: ModrinthProjectDetail?  // 预加载的项目详情（通用：整合包/普通资源）
    @State private var preloadedCompatibleGames: [GameVersionInfo] = []  // 预检测的兼容游戏列表
    @State private var isDisabled: Bool = false  // 资源是否被禁用
    @Binding var isResourceDisabled: Bool  // 暴露给父视图的禁用状态（用于置灰效果）
    @State private var currentFileName: String?  // 当前文件名（跟踪重命名后的文件名）
    @State private var hasDownloadedInSheet = false  // 标记在 sheet 中是否下载成功
    @State private var oldFileNameForUpdate: String?  // 更新前的旧文件名（用于更新时删除旧文件）
    @Binding var selectedItem: SidebarItem
    var onResourceChanged: (() -> Void)?
    /// 启用/禁用状态切换后的回调（仅本地资源列表使用）
    var onToggleDisableState: ((Bool) -> Void)?
    /// 更新成功回调：仅更新当前条目的 hash 与列表项，不全局扫描。参数 (projectId, oldFileName, newFileName, newHash)
    var onResourceUpdated: ((String, String, String, String?) -> Void)?
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
        scannedDetailIds: Binding<Set<String>> = .constant([]),
        isResourceDisabled: Binding<Bool> = .constant(false),
        onResourceUpdated: ((String, String, String, String?) -> Void)? = nil,
        onToggleDisableState: ((Bool) -> Void)? = nil
    ) {
        self.project = project
        self.selectedVersions = selectedVersions
        self.selectedLoaders = selectedLoaders
        self.gameInfo = gameInfo
        self.query = query
        self.type = type
        self._selectedItem = selectedItem
        self.onResourceChanged = onResourceChanged
        self._scannedDetailIds = scannedDetailIds
        self._isResourceDisabled = isResourceDisabled
        self.onResourceUpdated = onResourceUpdated
        self.onToggleDisableState = onToggleDisableState
    }

    var body: some View {

        HStack(spacing: 8) {
            // 更新按钮（仅在 local 模式且有更新时显示）
            if type == false && addButtonState == .update {
                Button(action: handleUpdateAction) {
                    if isUpdateButtonLoading {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Text("resource.update".localized())
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .font(.caption2)
                .controlSize(.small)
                .disabled(addButtonState == .loading || isUpdateButtonLoading)
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
                    // 检测是否有新版本（仅在 local 模式）
                    checkForUpdate()
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
                .keyboardShortcut(.defaultAction)  // 绑定回车键

                Button("common.cancel".localized(), role: .cancel) {}
            } message: {
                Text(
                    String(
                        format: "resource.delete.confirm".localized(),
                        project.title
                    )
                )
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
            // 新增：游戏资源安装 sheet（复用全局资源安装逻辑，预置游戏信息）
            .sheet(
                isPresented: $showGameResourceInstallSheet,
                onDismiss: {
                    // 重置更新按钮的loading状态
                    isUpdateButtonLoading = false
                    // 如果下载成功，状态已经在 sheet 中设置好了
                    // 如果只是关闭 sheet（没有下载）或下载失败
                    if !hasDownloadedInSheet {
                        // 如果是取消更新操作（oldFileNameForUpdate 不为空），保持更新状态
                        // 否则设置为安装状态
                        if oldFileNameForUpdate != nil {
                            // 取消更新操作，保持更新按钮显示
                            // 不需要改变 addButtonState，保持 .update 状态
                        } else {
                            addButtonState = .idle
                        }
                        // 如果取消更新操作或下载失败，清理旧文件名（不删除文件）
                        // 只有在下载成功时才会删除旧文件
                        oldFileNameForUpdate = nil
                    }
                    // 重置下载标志
                    hasDownloadedInSheet = false
                    // 清理预加载的数据
                    preloadedDetail = nil
                },
                content: {
                    if let gameInfo = gameInfo {
                        GameResourceInstallSheet(
                            project: project,
                            resourceType: query,
                            gameInfo: gameInfo,
                            isPresented: $showGameResourceInstallSheet,
                            preloadedDetail: preloadedDetail,
                            isUpdateMode: oldFileNameForUpdate != nil
                        ) { newFileName, newHash in
                            // 下载成功，标记并更新状态
                            hasDownloadedInSheet = true
                            addToScannedDetailIds(hash: newHash)

                            let wasUpdate = (oldFileNameForUpdate != nil)
                            let oldF = oldFileNameForUpdate
                            // 如果是更新操作，先删除旧文件（isUpdate: true 不触发 onResourceChanged）
                            if let old = oldF {
                                deleteFile(fileName: old, isUpdate: true)
                                oldFileNameForUpdate = nil
                            }
                            // 更新流程：仅刷新当前条目的 hash 与列表项，不全局扫描
                            if wasUpdate, let new = newFileName, let old = oldF {
                                onResourceUpdated?(project.projectId, old, new, newHash)
                                currentFileName = new
                            } else if !type {
                                currentFileName = nil
                            }
                            if type == false {
                                checkForUpdate()
                            } else {
                                addButtonState = .installed
                            }
                            preloadedDetail = nil
                        }
                        .environmentObject(gameRepository)
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
        // 使用 project.fileName 删除
        deleteFile(fileName: project.fileName)
    }

    // 根据指定文件名删除文件
    // - Parameter isUpdate: 若为 true 表示来自更新流程（删除旧文件），不调用 onResourceChanged
    private func deleteFile(fileName: String?, isUpdate: Bool = false) {
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

        // 使用传入的 fileName 删除
        guard let fileName = fileName else {
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
        if !isUpdate {
            onResourceChanged?()
        }
    }

    // MARK: - Actions
    /// 处理更新按钮的点击
    @MainActor
    private func handleUpdateAction() {
        if !type {
            // 保存旧文件名，用于更新后删除
            oldFileNameForUpdate = currentFileName ?? project.fileName
            isUpdateButtonLoading = true
            Task {
                // 加载项目详情并打开游戏资源安装 sheet（复用全局资源安装逻辑）
                await loadGameResourceInstallDetailBeforeOpeningSheet()
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
                    // 加载项目详情并打开游戏资源安装 sheet（复用全局资源安装逻辑）
                    await loadGameResourceInstallDetailBeforeOpeningSheet()
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
                    // 打开GlobalResourceSheet来选择安装到的游戏
                    await loadProjectDetailBeforeOpeningSheet()
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
        defer {
            Task { @MainActor in
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
        defer {
            Task { @MainActor in
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

    // 新增：在打开游戏资源安装 sheet 前加载项目详情（复用全局资源安装逻辑）
    private func loadGameResourceInstallDetailBeforeOpeningSheet() async {
        guard gameInfo != nil else {
            await MainActor.run {
                addButtonState = .idle
            }
            return
        }

        defer {
            Task { @MainActor in
                // 重置更新按钮的loading状态
                isUpdateButtonLoading = false
                // 只有在非更新操作时才重置状态
                // 如果是更新操作（oldFileNameForUpdate 不为空），保持当前状态
                if oldFileNameForUpdate == nil {
                    addButtonState = .idle
                }
            }
        }

        // 重置下载标志
        await MainActor.run {
            hasDownloadedInSheet = false
        }

        // 加载项目详情（和全局资源安装使用相同的逻辑）
        guard let result = await ResourceDetailLoader.loadProjectDetail(
            projectId: project.projectId,
            gameRepository: gameRepository,
            resourceType: query
        ) else {
            return
        }

        // 先设置 preloadedDetail
        await MainActor.run {
            preloadedDetail = result.detail
        }

        // 等待主线程周期后再显示 sheet
        await MainActor.run {
            // 只有当 preloadedDetail 不为 nil 时才显示 sheet
            if preloadedDetail != nil {
                showGameResourceInstallSheet = true
            }
        }
    }

    // 新增：检测是否有新版本（仅在 local 模式）
    private func checkForUpdate() {
        guard let gameInfo = gameInfo,
              type == false,  // 仅在 local 模式
              !isDisabled,  // 如果资源被禁用，不参与检测更新
              !project.projectId.hasPrefix("local_") && !project.projectId.hasPrefix("file_")  // 排除本地文件资源
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

    // 新增：在安装完成后更新 scannedDetailIds（使用hash）
    private func addToScannedDetailIds(hash: String? = nil) {
        // 如果有hash，使用hash；否则暂时不添加
        // 实际使用时，应该在下载完成后获取hash并调用此函数
        if let hash = hash {
            scannedDetailIds.insert(hash)
        }
    }

    private func updateDisableState() {
        // 使用 currentFileName 如果存在，否则使用 project.fileName
        let fileName = currentFileName ?? project.fileName
        isDisabled = ResourceEnableDisableManager.isDisabled(fileName: fileName)
        // 同步更新暴露给父视图的状态
        isResourceDisabled = isDisabled
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
            // 同步更新暴露给父视图的状态
            isResourceDisabled = isDisabled

            // 通知外部本地资源的启用/禁用状态已变更
            onToggleDisableState?(isDisabled)
        } catch {
            Logger.shared.error("切换资源启用状态失败: \(error.localizedDescription)")
        }
    }
}
