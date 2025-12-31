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
    @State private var sortIndex: String = AppConstants.modrinthIndex
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
    @StateObject private var gameSettings = GameSettingsManager.shared
    // 数据源：从设置中读取默认值，但可以临时更改（不影响设置）
    @State private var dataSource: DataSource = GameSettingsManager.shared.defaultAPISource
    // 搜索文本状态，用于保留从详情页返回时的搜索内容
    @State private var searchText: String = ""

    @State private var showingInspector: Bool = false

    // MARK: - Body
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // 侧边栏
            SidebarView(selectedItem: $selectedItem, gameType: $gameType)
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
                gameId: $gameId,
                dataSource: $dataSource
            )
            .toolbar { ContentToolbarView() }.navigationSplitViewColumnWidth(
                min: 235,
                ideal: 240,
                max: 280
            )
        } detail: {

            DetailView(
                selectedItem: $selectedItem,
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
                dataSource: $dataSource,
                searchText: $searchText
            )
            .toolbar {
                DetailToolbarView(
                    selectedItem: $selectedItem,
                    gameResourcesType: $gameResourcesType,
                    gameType: $gameType,
                    versionCurrentPage: $versionCurrentPage,
                    versionTotal: $versionTotal,
                    project: $loadedProjectDetail,
                    selectProjectId: $selectedProjectId,
                    selectedTab: $selectedTab,
                    gameId: $gameId,
                    dataSource: $dataSource
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
        .onChange(of: gameRepository.workingPathChanged) { _, _ in
            // 当工作目录改变时，切换到mod选择界面
            selectedItem = .resource(.mod)
            gameType = true
            // 重新扫描所有游戏
            scanAllGamesModsDirectory()
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
        // 清空搜索文本
        if self.gameId != nil, selectedProjectId == nil {
            searchText = ""
        }

        // 不要强制设置 gameType，保持用户之前的选择
        // 只有在 gameType 为服务器且之前没选过游戏时才设置为本地资源
        if gameType == true && self.gameId == nil {
            // 如果是从资源页面切换到游戏页面，且之前没有选择游戏，则设置为本地资源
            gameType = false
        }

        let game = gameRepository.getGame(by: gameId)

        if let loader = game?.modLoader.lowercased() {
            let currentType = gameResourcesType.lowercased()

            if loader == "vanilla" {
                // 仅当当前选择与 vanilla 不兼容时才纠正，避免覆盖用户选择
                if currentType == "mod" || currentType == "shader" || currentType == "modpack" {
                    gameResourcesType = "datapack"
                }
            } else {
                if selectedProjectId == nil {
                    gameResourcesType = "mod"
                }
            }
        }

        self.gameId = gameId
        self.selectedProjectId = nil
        // 更新选中的游戏管理器，供设置页面使用
        selectedGameManager.setSelectedGame(gameId)
    }

    private func handleGameToGameTransition(
        from oldId: String,
        to newId: String
    ) {
        // 清空搜索文本
        searchText = ""

        // 切换游戏时，强制使用本地模式
        gameType = false

        let game = gameRepository.getGame(by: newId)
        if let loader = game?.modLoader.lowercased() {
            gameResourcesType = (loader == "vanilla") ? "datapack" : "mod"
        }

        self.gameId = newId
        // 更新选中的游戏管理器，供设置页面使用
        selectedGameManager.setSelectedGame(newId)
    }

    // MARK: - Resource Reset
    private func resetToResourceDefaults() {
        // 清空搜索文本
        if case .resource = selectedItem {
            if gameId == nil {
                searchText = ""
            }
        }

        // 清除选中的游戏，因为切换到资源页面
        selectedGameManager.clearSelection()

        // 资源目录应该始终使用服务器模式（从Modrinth搜索）
        if !gameType && self.selectedProjectId == nil {
            gameType = true
        }

        // 排序方式回到默认值
        sortIndex = AppConstants.modrinthIndex

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
            searchText = ""
        }
        if self.loadedProjectDetail != nil && self.gameId != nil
            && self.selectedProjectId != nil {
            self.gameId = nil
            self.loadedProjectDetail = nil
            self.selectedProjectId = nil
        }
    }

    // MARK: - Scanning Methods

    /// 扫描所有游戏的 mods 目录
    /// 异步执行，不会阻塞 UI
    private func scanAllGamesModsDirectory() {
        Task {
            let games = gameRepository.games
            Logger.shared.info("开始扫描 \(games.count) 个游戏的 mods 目录")

            // 并发扫描所有游戏
            await withTaskGroup(of: Void.self) { group in
                for game in games {
                    group.addTask {
                        await ModScanner.shared.scanGameModsDirectory(game: game)
                    }
                }
            }

            Logger.shared.info("完成所有游戏的 mods 目录扫描")
        }
    }
}
