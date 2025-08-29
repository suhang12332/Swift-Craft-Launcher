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
    @EnvironmentObject private var gameRepository: GameRepository
    @State private var addButtonState: ModrinthDetailCardView.AddButtonState =
        .idle
    @State private var showDeleteAlert = false
    @State private var showNoGameAlert = false
    @ObservedObject private var gameSettings = GameSettingsManager.shared
    @StateObject private var depVM = DependencySheetViewModel()
    @State private var isDownloadingAllDependencies = false
    @State private var isDownloadingMainResourceOnly = false
    @State private var showGlobalResourceSheet = false
    @State private var showModPackDownloadSheet = false  // 新增：整合包下载 sheet
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
        forceInstalled: Bool = false
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
    }

    var body: some View {
        VStack {
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
                                    gameRepository: gameRepository,
                                    updateButtonState: updateButtonState
                                )
                        } else {
                            // 首次点击"全部下载"
                            await GameResourceHandler
                                .downloadAllDependenciesAndMain(
                                    project: project,
                                    gameInfo: gameInfo,
                                    depVM: depVM,
                                    query: query,
                                    gameRepository: gameRepository,
                                    updateButtonState: updateButtonState
                                )
                        }
                    },
                    onRetry: { dep in
                        Task {
                            await GameResourceHandler.retryDownloadDependency(
                                dep: dep,
                                gameInfo: gameInfo,
                                depVM: depVM,
                                query: query,
                                gameRepository: gameRepository
                            )
                        }
                    },
                    onDownloadMainOnly: {
                        isDownloadingMainResourceOnly = true
                        await GameResourceHandler.downloadSingleResource(
                            project: project,
                            gameInfo: gameInfo,
                            query: query,
                            gameRepository: gameRepository,
                            updateButtonState: updateButtonState
                        )
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
                        isPresented: $showGlobalResourceSheet
                    )
                    .environmentObject(gameRepository)
                }
            )
            // 新增：整合包下载 sheet
            .sheet(
                isPresented: $showModPackDownloadSheet,
                onDismiss: {
                    addButtonState = .idle
                    scanResourcesIfAvailable()
                },
                content: {
                    ModPackDownloadSheet(
                        projectId: project.projectId,
                        gameInfo: gameInfo,
                        query: query
                    )
                    .environmentObject(gameRepository)
                }
            )
        }
        .alert(isPresented: $showNoGameAlert) {
            Alert(
                title: Text("no_local_game.title".localized()),
                message: Text("no_local_game.message".localized()),
                dismissButton: .default(Text("common.confirm".localized()))
            )
        }
    }

    // MARK: - UI Components
    private var buttonLabel: some View {
        switch addButtonState {
        case .idle:
            AnyView(Text("resource.add".localized()))
        case .loading:
            AnyView(ProgressView())
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

    // 新增：根据当前 project 查找 fileURL（示例实现，需根据实际逻辑补全）
    private func deleteFile() {
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
        let details = ModScanner.shared.localModDetails(in: resourceDir)
        for (file, _, detail) in details {
            if let detail = detail, detail.id == project.projectId {
                GameResourceHandler.performDelete(fileURL: file)
                scanResourcesIfAvailable()
                return  // 删除后立即返回
            }
        }

        // 如果没有找到要删除的文件
        let globalError = GlobalError.resource(
            chineseMessage: "未找到要删除的文件: \(project.title)",
            i18nKey: "error.resource.file_not_found_for_deletion",
            level: .notification
        )
        Logger.shared.error("删除文件失败: \(globalError.chineseMessage)")
        GlobalErrorHandler.shared.handle(globalError)
    }

    // MARK: - Actions
    @MainActor
    private func handleButtonAction() {
        if case .game = selectedItem {
            switch addButtonState {
            case .idle:
                // 新增：对整合包的特殊处理
                if query == "modpack" {
                    showModPackDownloadSheet = true
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
                                gameRepository: gameRepository,
                                updateButtonState: updateButtonState
                            )
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
                                    gameRepository: gameRepository,
                                    updateButtonState: updateButtonState
                                )
                            }
                        }
                    } else {
                        // 其他类型直接下载
                        await GameResourceHandler.downloadSingleResource(
                            project: project,
                            gameInfo: gameInfo,
                            query: query,
                            gameRepository: gameRepository,
                            updateButtonState: updateButtonState
                        )
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
                // 新增：对整合包的特殊处理
                if query == "modpack" {
                    if gameRepository.games.isEmpty {
                        showNoGameAlert = false
                    }
                    showModPackDownloadSheet = true
                    return
                }

                addButtonState = .loading
                Task {
                    if gameRepository.games.isEmpty {
                        showNoGameAlert = true
                    } else {
                        showGlobalResourceSheet = true
                    }
                    addButtonState = .idle
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
        if let gameInfo = gameInfo,
            let resourceDir = AppPaths.resourceDirectory(
                for: query,
                gameName: gameInfo.gameName
            ) {
            if ModScanner.shared.isModInstalledSync(
                projectId: project.projectId,
                in: resourceDir
            ) {
                addButtonState = .installed
                return
            }
        }
        addButtonState = .idle
    }

    // 新增：安全调用外部 scanResources（需在父视图注入或传递）
    private func scanResourcesIfAvailable() {
        onResourceChanged?()
    }
}
