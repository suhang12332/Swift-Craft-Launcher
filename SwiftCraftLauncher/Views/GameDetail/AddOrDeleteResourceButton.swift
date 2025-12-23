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
    @State private var activeAlert: AlertType? = nil
    @StateObject private var gameSettings = GameSettingsManager.shared
    @StateObject private var depVM = DependencySheetViewModel()
    @State private var isDownloadingAllDependencies = false
    @State private var isDownloadingMainResourceOnly = false
    @State private var showGlobalResourceSheet = false
    @State private var showModPackDownloadSheet = false  // 新增：整合包下载 sheet
    @State private var preloadedDetail: ModrinthProjectDetail?  // 预加载的项目详情（通用：整合包/普通资源）
    @State private var isLoadingProjectDetail = false  // 是否正在加载项目详情
    @State private var isDisabled: Bool = false  // 资源是否被禁用
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
//            // 禁用/启用按钮（仅本地资源显示）
//            if type == false {
//                Button(action: toggleDisableState) {
//                    Text(isDisabled ? "resource.enable".localized() : "resource.disable".localized())
//                }
//                .buttonStyle(.borderedProminent)
//                .tint(.accentColor)  // 或 .tint(.primary) 但一般用 accentColor 更美观
//                .font(.caption2)
//                .controlSize(.small)
//            }

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
                    checkDisableState()
                } else {
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
                                    updateButtonState()
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
                                    updateButtonState()
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
                            updateButtonState()
                        }
                        isDownloadingMainResourceOnly = false
                        depVM.showDependenciesSheet = false
                    }
                )
            }
            .sheet(
                isPresented: $showGlobalResourceSheet,
                onDismiss: {
                    addButtonState = .idle
                },
                content: {
                    GlobalResourceSheet(
                        project: project,
                        resourceType: query,
                        isPresented: $showGlobalResourceSheet,
                        preloadedDetail: preloadedDetail
                    )
                    .environmentObject(gameRepository)
                    .onDisappear {
                        // sheet 关闭时清理预加载的数据
                        preloadedDetail = nil
                    }
                }
            )
            // 新增：整合包下载 sheet
            .sheet(
                isPresented: $showModPackDownloadSheet,
                onDismiss: {
                    addButtonState = .idle
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
                                updateButtonState()
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
                                    updateButtonState()
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
                            updateButtonState()
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

        // 只检查 scannedDetailIds 是否包含当前项目的 slug
        // 如果包含，说明该资源已在扫描列表中，标记为已安装
        // 移除同步扫描以提高性能，避免卡顿
        if scannedDetailIds.contains(project.slug) {
            addButtonState = .installed
            return
        }

        // 检查 query 是否是有效的资源类型
        let validResourceTypes = ["mod", "datapack", "shader", "resourcepack"]
        let queryLowercased = query.lowercased()

        // 如果 query 是 modpack 或无效的资源类型，设置为 idle
        if queryLowercased == "modpack" || !validResourceTypes.contains(queryLowercased) {
            addButtonState = .idle
            return
        }
        addButtonState = .idle
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

        await MainActor.run {
            preloadedDetail = detail
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

    // 新增：在安装完成后更新 scannedDetailIds（使用slug）
    private func addToScannedDetailIds() {
        scannedDetailIds.insert(project.slug)
    }

    private func checkDisableState() {
        isDisabled = (project.fileName?.hasSuffix(".disable") ?? false)
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

        guard let fileName = project.fileName else {
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
            // 根据新的文件名更新状态：如果新文件名以 .disable 结尾，则 isDisabled = true
            isDisabled = targetFileName.hasSuffix(".disable")
            onResourceChanged?()
        } catch {
            Logger.shared.error("切换资源启用状态失败: \(error.localizedDescription)")
        }
    }
}
