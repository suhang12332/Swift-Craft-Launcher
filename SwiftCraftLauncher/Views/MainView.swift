//
//  MainView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/5/30.
//

import SwiftUI

struct MainView: View {
    // MARK: - State & Environment
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var selectedItem: SidebarItem = .resource(.mod)
    @StateObject private var general = GeneralSettingsManager.shared
    @StateObject private var selectedGameManager = SelectedGameManager.shared
    @EnvironmentObject var gameRepository: GameRepository

    // MARK: - Resource/Project State
    @State private var sortIndex: String = "relevance"
    @State private var selectedVersions: [String] = []
    @State private var selectedLicenses: [String] = []
    @State private var selectedCategories: [String] = []
    @State private var selectedFeatures: [String] = []
    @State private var selectedResolutions: [String] = []
    @State private var selectedPerformanceImpact: [String] = []
    @State private var selectedLoaders: [String] = []
    @State private var selectedProjectId: String?
    @State private var loadedProjectDetail: ModrinthProjectDetail?
    @State private var selectedTab = 0

    // MARK: - Version/Detail State
    @State private var versionCurrentPage: Int = 1
    @State private var versionTotal: Int = 0
    @State private var gameResourcesType = "mod"
    @State private var gameType = true  // false = local, true = server
    @State private var gameId: String?
    @State private var isScanComplete = false  // 扫描完成状态，用于控制工具栏按钮

    @State private var showingInspector: Bool = false

    // MARK: - Body
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // 侧边栏
            SidebarView(selectedItem: $selectedItem)
                .navigationSplitViewColumnWidth(min: 168, ideal: 168, max: 168)
        } content: {

            ContentView(
                selectedItem: selectedItem,
                selectedVersions: $selectedVersions,
                selectedLicenses: $selectedLicenses,
                selectedCategories: $selectedCategories,
                selectedFeatures: $selectedFeatures,
                selectedResolutions: $selectedResolutions,
                selectedPerformanceImpact: $selectedPerformanceImpact,
                selectProjectId: $selectedProjectId,
                loadedProjectDetail: $loadedProjectDetail,
                gameResourcesType: $gameResourcesType,
                selectedLoaders: $selectedLoaders,
                gameType: $gameType,
                gameId: $gameId
            )
            .toolbar { ContentToolbarView() }.navigationSplitViewColumnWidth(
                min: 235,
                ideal: 240,
                max: 280
            )
        } detail: {

            DetailView(
                selectedItem: $selectedItem,
                sortIndex: $sortIndex,
                gameResourcesType: $gameResourcesType,
                selectedVersions: $selectedVersions,
                selectedCategories: $selectedCategories,
                selectedFeatures: $selectedFeatures,
                selectedResolutions: $selectedResolutions,
                selectedPerformanceImpact: $selectedPerformanceImpact,
                selectedProjectId: $selectedProjectId,
                loadedProjectDetail: $loadedProjectDetail,
                selectTab: $selectedTab,
                versionCurrentPage: $versionCurrentPage,
                versionTotal: $versionTotal,
                gameType: $gameType,
                selectedLoader: $selectedLoaders,
                isScanComplete: $isScanComplete
            )
            .toolbar {
                DetailToolbarView(
                    selectedItem: $selectedItem,
                    sortIndex: $sortIndex,
                    gameResourcesType: $gameResourcesType,
                    gameType: $gameType,
                    versionCurrentPage: $versionCurrentPage,
                    versionTotal: $versionTotal,
                    project: $loadedProjectDetail,
                    selectProjectId: $selectedProjectId,
                    selectedTab: $selectedTab,
                    gameId: $gameId,
                    isScanComplete: $isScanComplete
                )
            }
        }
        .frame(minWidth: 900, minHeight: 500)
        .onChange(of: selectedItem) { oldValue, newValue in
            handleSidebarItemChange(from: oldValue, to: newValue)
        }
        .onChange(of: selectedProjectId) { oldValue, newValue in
            // 优化：仅在 selectedProjectId 实际变化且 loadedProjectDetail 不为 nil 时清空
            if oldValue != newValue && loadedProjectDetail != nil {
                loadedProjectDetail = nil
            }
        }
    }

    // MARK: - Sidebar Item Change Handlers
    private func handleSidebarItemChange(
        from oldValue: SidebarItem,
        to newValue: SidebarItem
    ) {
        switch (oldValue, newValue) {
        case (.resource, .game(let id)):
            handleResourceToGameTransition(gameId: id)
        case (.game, .resource):
            resetToResourceDefaults()
        case let (.game(oldId), .game(newId)):
            handleGameToGameTransition(from: oldId, to: newId)
        case (.resource, .resource):
            resetToResourceDefaults()
        }
    }

    // MARK: - Transition Helpers
    private func handleResourceToGameTransition(gameId: String) {
        // 不要强制设置 gameType，保持用户之前的选择
        // 只有在 gameType 为服务器且之前没选过游戏时才设置为本地资源
        if gameType == true && self.gameId == nil {
            // 如果是从资源页面切换到游戏页面，且之前没有选择游戏，则设置为本地资源
            gameType = false
        }

        let game = gameRepository.getGame(by: gameId)

        if let loader = game?.modLoader.lowercased() {
            if loader == "vanilla" {
                // 对于 vanilla，如果当前资源类型是 mod，则切换为 datapack，否则保持用户原来的选择
                if gameResourcesType.lowercased() == "mod" {
                    gameResourcesType = "datapack"
                }
            } else {
                // 非 vanilla 一律使用 mod
                gameResourcesType = "mod"
            }
        }

        self.gameId = gameId
        self.selectedProjectId = nil
        // 重置扫描状态
        if self.gameId == nil {
            self.isScanComplete = false
        }
        if self.gameId != nil {
            self.isScanComplete = true
        }
        // 更新选中的游戏管理器，供设置页面使用
        selectedGameManager.setSelectedGame(gameId)
    }

    private func handleGameToGameTransition(
        from oldId: String,
        to newId: String
    ) {
        // 切换游戏时，强制使用本地模式
        gameType = false

        let game = gameRepository.getGame(by: newId)
        if let loader = game?.modLoader.lowercased() {
            gameResourcesType = (loader == "vanilla") ? "datapack" : "mod"
        }

        self.gameId = newId
        // 重置扫描状态
        self.isScanComplete = false
        // 更新选中的游戏管理器，供设置页面使用
        selectedGameManager.setSelectedGame(newId)
    }

    // MARK: - Resource Reset
    private func resetToResourceDefaults() {
        // 清除选中的游戏，因为切换到资源页面
        selectedGameManager.clearSelection()

        // 重置扫描状态（资源页面不需要扫描，设为 true）
        isScanComplete = true

        // 排序方式回到默认值
        sortIndex = "relevance"

        // 保证资源类型与当前侧边栏选择一致
        if case .resource(let resourceType) = selectedItem {
            gameResourcesType = resourceType.rawValue
        }

        // 清空所有筛选条件
        selectedVersions.removeAll()
        selectedLicenses.removeAll()
        selectedCategories.removeAll()
        selectedFeatures.removeAll()
        selectedResolutions.removeAll()
        selectedPerformanceImpact.removeAll()
        selectedLoaders.removeAll()

        // 重置分页和 Tab
        selectedTab = 0
        versionCurrentPage = 1
        versionTotal = 0

        // 清理 project/game 关联状态，防止产生不一致
        if gameId == nil && self.selectedProjectId != nil {
            self.selectedProjectId = nil
        }
        if self.selectedProjectId == nil && self.gameId != nil {
            self.gameId = nil
        }
        if self.loadedProjectDetail != nil && self.gameId != nil
            && self.selectedProjectId != nil {
            self.gameId = nil
            self.loadedProjectDetail = nil
            self.selectedProjectId = nil
        }
    }
}
