//
//  GameInfoDetailView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/2.
//

import SwiftUI

// MARK: - Window Delegate
// 已移除 NSWindowDelegate 相关代码，纯 SwiftUI 不再需要

// MARK: - Views
struct GameInfoDetailView: View {
    let game: GameVersionInfo

    @Binding var query: String
    @Binding var dataSource: DataSource
    @Binding var selectedVersions: [String]
    @Binding var selectedCategories: [String]
    @Binding var selectedFeatures: [String]
    @Binding var selectedResolutions: [String]
    @Binding var selectedPerformanceImpact: [String]
    @Binding var selectedProjectId: String?
    @Binding var selectedLoaders: [String]
    @Binding var gameType: Bool  // false = local,   = server
    @EnvironmentObject var gameRepository: GameRepository
    @Binding var selectedItem: SidebarItem
    @Binding var searchText: String
    @StateObject private var cacheManager = CacheManager()
    @State private var localRefreshToken = UUID()

    // 扫描结果：detailId Set，用于快速查找（O(1)）
    @State private var scannedResources: Set<String> = []

    // 使用稳定的 header，避免因 cacheInfo 更新导致重建
    @State private var remoteHeader: AnyView?
    @State private var localHeader: AnyView?

    var body: some View {
        return Group {
            if gameType {
                GameRemoteResourceView(
                    game: game,
                    query: $query,
                    selectedVersions: $selectedVersions,
                    selectedCategories: $selectedCategories,
                    selectedFeatures: $selectedFeatures,
                    selectedResolutions: $selectedResolutions,
                    selectedPerformanceImpact: $selectedPerformanceImpact,
                    selectedProjectId: $selectedProjectId,
                    selectedLoaders: $selectedLoaders,
                    selectedItem: $selectedItem,
                    gameType: $gameType,
                    header: remoteHeader,
                    scannedDetailIds: $scannedResources,
                    dataSource: $dataSource,
                    searchText: $searchText
                )
            } else {
                GameLocalResourceView(
                    game: game,
                    query: query,
                    header: localHeader,
                    selectedItem: $selectedItem,
                    selectedProjectId: $selectedProjectId,
                    refreshToken: localRefreshToken,
                    searchText: $searchText
                )
            }
        }
        // 刷新逻辑：
        // 1. 游戏名变化时刷新
        // 2. gameType 变化且游戏名不变时刷新
        .onChange(of: game.gameName) { _, _ in
            // 游戏名变化时刷新
            performRefresh()
        }
        .onChange(of: gameType) { _, _ in
            performRefresh()
        }
        // 4. 详情关闭时（selectedProjectId 从非 nil 变为 nil），重新扫描已安装资源，
        //    用于刷新远程列表中的安装状态（安装按钮）
        .onChange(of: selectedProjectId) { oldValue, newValue in
            if oldValue != nil && newValue == nil {
                resetScanState()
                scanAllResources()
            }
        }
        // 3. 资源类型（query）变化时，重新扫描已安装资源，用于更新安装状态
        .onChange(of: query) { _, _ in
            resetScanState()
            scanAllResources()
        }
        .onAppear {
            // 初始化 header
            updateHeaders()
            cacheManager.calculateGameCacheInfo(game.gameName)
        }
        .onChange(of: cacheManager.cacheInfo) { _, _ in
            // 当 cacheInfo 更新时，更新 header（但不重建整个视图）
            updateHeaders()
        }
        .onDisappear {
            // 页面关闭后清除所有数据
            clearAllData()
        }
    }

    // MARK: - 刷新逻辑
    /// 执行刷新操作（游戏名变化或 gameType 变化且游戏名不变时调用）
    private func performRefresh() {
        updateHeaders()
        cacheManager.calculateGameCacheInfo(game.gameName)
        // 仅在本地视图时刷新本地资源
        if !gameType {
            triggerLocalRefresh()
        }
        // 重新扫描资源
        resetScanState()
        scanAllResources()
    }

    private func triggerLocalRefresh() {
        // 仅在本地视图时更新刷新令牌
        guard !gameType else { return }
        localRefreshToken = UUID()
    }

    // MARK: - 更新 Header
    /// 更新 header 视图，但不重建整个 GameRemoteResourceView
    private func updateHeaders() {
        remoteHeader = AnyView(
            GameHeaderListRow(
                game: game,
                cacheInfo: cacheManager.cacheInfo,
                query: query
            ) {
                triggerLocalRefresh()
            }
        )
        localHeader = AnyView(
            GameHeaderListRow(
                game: game,
                cacheInfo: cacheManager.cacheInfo,
                query: query
            ) {
                triggerLocalRefresh()
            }
        )
    }

    // MARK: - 清除数据
    /// 清除页面所有数据
    private func clearAllData() {
        // 重置缓存信息为默认值
        cacheManager.cacheInfo = CacheInfo(fileCount: 0, totalSize: 0)
        // 仅在本地视图时重置刷新令牌
        if !gameType {
            localRefreshToken = UUID()
        }
        // 重置扫描结果
        scannedResources = []
    }

    // MARK: - 重置扫描状态
    /// 重置扫描状态，准备重新扫描
    private func resetScanState() {
        scannedResources = []
    }

    // MARK: - 扫描所有资源
    /// 异步扫描所有资源，收集 detailId（不阻塞视图渲染）
    private func scanAllResources() {
        // Modpacks don't have a local directory to scan
        if query.lowercased() == "modpack" {
            scannedResources = []
            return
        }

        guard let resourceDir = AppPaths.resourceDirectory(
            for: query,
            gameName: game.gameName
        ) else {
            scannedResources = []
            return
        }

        // 检查目录是否存在且可访问
        guard FileManager.default.fileExists(atPath: resourceDir.path) else {
            // 目录不存在，直接返回
            scannedResources = []
            return
        }

        // 使用 Task 创建异步任务，确保不阻塞视图渲染
        // 所有耗时操作在后台线程执行，只有更新状态时才回到主线程
        Task {
            do {
                // 调用新的异步接口，只获取 detailId（直接返回 Set）
                let detailIds = try await ModScanner.shared.scanAllDetailIdsThrowing(in: resourceDir)

                // 回到主线程更新状态
                await MainActor.run {
                    scannedResources = detailIds
                }
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("扫描所有资源失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)

                // 回到主线程更新状态
                await MainActor.run {
                    scannedResources = []
                }
            }
        }
    }
}
