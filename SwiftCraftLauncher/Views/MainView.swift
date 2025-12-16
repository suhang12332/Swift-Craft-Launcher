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
    @State private var currentPage: Int = 1
    @State private var totalItems: Int = 0
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
                currentPage: $currentPage,
                totalItems: $totalItems,
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
                selectedLoader: $selectedLoaders
            )
            .toolbar {
                DetailToolbarView(
                    selectedItem: $selectedItem,
                    sortIndex: $sortIndex,
                    gameResourcesType: $gameResourcesType,
                    gameType: $gameType,
                    currentPage: $currentPage,
                    versionCurrentPage: $versionCurrentPage,
                    versionTotal: $versionTotal,
                    totalItems: totalItems,
                    project: $loadedProjectDetail,
                    selectProjectId: $selectedProjectId,
                    selectedTab: $selectedTab,
                    gameId: $gameId
                )
            }
        }
        //        .inspector(isPresented: $showingInspector) {
        //            ContentView(
        //                selectedItem: selectedItem,
        //                selectedVersions: $selectedVersions,
        //                selectedLicenses: $selectedLicenses,
        //                selectedCategories: $selectedCategories,
        //                selectedFeatures: $selectedFeatures,
        //                selectedResolutions: $selectedResolutions,
        //                selectedPerformanceImpact: $selectedPerformanceImpact,
        //                selectProjectId: $selectedProjectId,
        //                loadedProjectDetail: $loadedProjectDetail,
        //                gameResourcesType: $gameResourcesType,
        //                selectedLoaders: $selectedLoaders,
        //                gameType: $gameType,
        //                gameId: $gameId
        //            )
        //            .toolbar {InspectorToolbar(showingInspector: $showingInspector)}.navigationSplitViewColumnWidth(min: 235, ideal: 240, max: .infinity)
        ////            ContentView().toolbar {InspectorToolbar(showingInspector: $showingInspector)}
        //        }

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
        // 只有在 gameType 未初始化时才设置为 false
        if self.gameType == true && self.gameId == nil {
            // 如果是从资源页面切换到游戏页面，且之前没有选择游戏，则设置为本地资源
            self.gameType = false
        }
        let game = gameRepository.getGame(by: gameId)
        self.gameResourcesType =
        game?.modLoader.lowercased() == "vanilla" ? self.gameResourcesType.lowercased() != "mod" ? self.gameResourcesType : "datapack" : "mod"
        self.gameId = gameId
        self.selectedProjectId = nil
        // 更新选中的游戏管理器，供设置页面使用
        selectedGameManager.setSelectedGame(gameId)
    }

    private func handleGameToGameTransition(
        from oldId: String,
        to newId: String
    ) {
        if self.gameType != false {
                self.gameType = false
        }
        // 保持用户之前选择的 gameType，不要强制修改
        let game = gameRepository.getGame(by: newId)
        self.gameResourcesType =
            game?.modLoader.lowercased() == "vanilla" ? "datapack" : "mod"
        self.gameId = newId
        // 更新选中的游戏管理器，供设置页面使用
        selectedGameManager.setSelectedGame(newId)
    }

    // MARK: - Resource Reset
    private func resetToResourceDefaults() {
        // 清除选中的游戏，因为切换到资源页面
        selectedGameManager.clearSelection()

        if self.gameType != true {
            self.gameType = true
        }

        if self.sortIndex != "relevance" {
            self.sortIndex = "relevance"
        }
        if case .resource(let resourceType) = selectedItem {
            if self.gameResourcesType != resourceType.rawValue {
                self.gameResourcesType = resourceType.rawValue
            }
        }
        if self.currentPage != 1 {
            self.currentPage = 1
        }
        if self.totalItems != 0 {
            self.totalItems = 0
        }
        if !self.selectedVersions.isEmpty {
            self.selectedVersions.removeAll()
        }
        if !self.selectedLicenses.isEmpty {
            self.selectedLicenses.removeAll()
        }
        if !self.selectedCategories.isEmpty {
            self.selectedCategories.removeAll()
        }
        if !self.selectedFeatures.isEmpty {
            self.selectedFeatures.removeAll()
        }
        if !self.selectedResolutions.isEmpty {
            self.selectedResolutions.removeAll()
        }
        if !self.selectedPerformanceImpact.isEmpty {
            self.selectedPerformanceImpact.removeAll()
        }
        if !self.selectedLoaders.isEmpty {
            self.selectedLoaders.removeAll()
        }

        if self.selectedTab != 0 {
            self.selectedTab = 0
        }
        if self.versionCurrentPage != 1 {
            self.versionCurrentPage = 1
        }
        if self.versionTotal != 0 {
            self.versionTotal = 0
        }
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
