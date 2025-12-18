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
    @Binding var sortIndex: String
    @Binding var selectedVersions: [String]
    @Binding var selectedCategories: [String]
    @Binding var selectedFeatures: [String]
    @Binding var selectedResolutions: [String]
    @Binding var selectedPerformanceImpact: [String]
    @Binding var selectedProjectId: String?
    @Binding var selectedLoaders: [String]
    @Binding var gameType: Bool  // false = local, true = server
    @EnvironmentObject var gameRepository: GameRepository
    @Binding var selectedItem: SidebarItem
    @StateObject private var cacheManager = CacheManager()
    @State private var localRefreshToken = UUID()
    
    // 扫描结果：ModrinthProjectDetail 数组
    @State private var scannedResources: [ModrinthProjectDetail] = []
    @State private var isScanComplete: Bool = false

    var body: some View {
        return Group {
            if gameType {
                GameRemoteResourceView(
                    game: game,
                    query: $query,
                    sortIndex: $sortIndex,
                    selectedVersions: $selectedVersions,
                    selectedCategories: $selectedCategories,
                    selectedFeatures: $selectedFeatures,
                    selectedResolutions: $selectedResolutions,
                    selectedPerformanceImpact: $selectedPerformanceImpact,
                    selectedProjectId: $selectedProjectId,
                    selectedLoaders: $selectedLoaders,
                    selectedItem: $selectedItem,
                    gameType: $gameType,
                    header: AnyView(
                        GameHeaderListRow(
                            game: game,
                            cacheInfo: cacheManager.cacheInfo,
                            query: query
                        ) {
                            triggerLocalRefresh()
                        }
                    ),
                    scannedDetailIds: scannedResources.map { $0.id }
                )
            } else {
                GameLocalResourceView(
                    game: game,
                    query: query,
                    header: AnyView(
                        GameHeaderListRow(
                            game: game,
                            cacheInfo: cacheManager.cacheInfo,
                            query: query
                        ) {
                            triggerLocalRefresh()
                        }
                    ),
                    selectedItem: $selectedItem,
                    selectedProjectId: $selectedProjectId,
                    refreshToken: localRefreshToken,
                    initialScannedResources: scannedResources,
                    isScanComplete: isScanComplete
                )
            }
        }
        // 优化：合并相关 onChange 以减少不必要的视图更新
        .onChange(of: game.gameName) { _, _ in
            cacheManager.calculateGameCacheInfo(game.gameName)
            triggerLocalRefresh()
            // 重新扫描资源
            resetScanState()
            scanAllResources()
        }
        .onChange(of: gameType) { oldValue, newValue in
            // 仅在 gameType 实际变化时扫描资源
            if oldValue != newValue {
                if newValue == false {
                    triggerLocalRefresh()
                    // 切换到本地视图时重新扫描
                    resetScanState()
                    scanAllResources()
                }
            }
        }
        .onChange(of: query) { oldValue, newValue in
            // 仅在 query 实际变化时扫描资源
            if oldValue != newValue {
                triggerLocalRefresh()
                // 重新扫描资源
                resetScanState()
                scanAllResources()
            }
        }
        .onAppear {
            cacheManager.calculateGameCacheInfo(game.gameName)
            // 页面进入时异步扫描所有资源
            if !isScanComplete {
                scanAllResources()
            }
        }
        .onDisappear {
            // 页面关闭后清除所有数据
            clearAllData()
        }
    }

    private func triggerLocalRefresh() {
        localRefreshToken = UUID()
    }

    // MARK: - 清除数据
    /// 清除页面所有数据
    private func clearAllData() {
        // 重置缓存信息为默认值
        cacheManager.cacheInfo = CacheInfo(fileCount: 0, totalSize: 0)
        // 重置刷新令牌
        localRefreshToken = UUID()
        // 重置扫描结果
        scannedResources = []
        isScanComplete = false
    }
    
    // MARK: - 重置扫描状态
    /// 重置扫描状态，准备重新扫描
    private func resetScanState() {
        scannedResources = []
        isScanComplete = false
    }
    
    // MARK: - 扫描所有资源
    /// 异步扫描所有资源，收集 title 和 detailId（不阻塞视图渲染）
    private func scanAllResources() {
        // 如果已经完成扫描，不重复扫描
        guard !isScanComplete else { return }
        
        // Modpacks don't have a local directory to scan
        if query.lowercased() == "modpack" {
            scannedResources = []
            isScanComplete = true
            return
        }
        
        guard let resourceDir = AppPaths.resourceDirectory(
            for: query,
            gameName: game.gameName
        ) else {
            scannedResources = []
            isScanComplete = true
            return
        }
        
        // 立即设置状态为未完成，不阻塞视图渲染
        isScanComplete = false
        
        // 使用 Task 创建异步任务，确保不阻塞视图渲染
        // 所有耗时操作在后台线程执行，只有更新状态时才回到主线程
        // 捕获 query 的值，避免在后台线程访问 @Binding
        let queryValue = query
        Task {
            do {
                // 使用 Task.detached 在后台线程执行扫描和处理，避免阻塞主线程
                let resources = await Task.detached(priority: .userInitiated) {
                    // 在后台线程执行扫描操作
                    let fileDetails = ModScanner.shared.localModDetails(in: resourceDir)
                    
                    var details: [ModrinthProjectDetail] = []
                    
                    // 处理扫描结果（在后台线程）
                    for (file, hash, detail) in fileDetails {
                        // 优先使用缓存的 detail，否则从缓存查询
                        if let cachedDetail = detail {
                            details.append(cachedDetail)
                        } else if let cachedDetail = AppCacheManager.shared.get(
                            namespace: queryValue,
                            key: hash,
                            as: ModrinthProjectDetail.self
                        ) {
                            details.append(cachedDetail)
                        }
                    }
                    
                    return details
                }.value
                
                // 回到主线程更新状态
                await MainActor.run {
                    scannedResources = resources
                    isScanComplete = true
                }
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("扫描所有资源失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
                
                // 回到主线程更新状态
                await MainActor.run {
                    scannedResources = []
                    isScanComplete = true
                }
            }
        }
    }
}
