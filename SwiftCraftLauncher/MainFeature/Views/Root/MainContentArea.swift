//
//  MainContentArea.swift
//  SwiftCraftLauncher
//
//  承载 filterState/detailState，将二者从 MainView 根节点下沉至此，
//  减少 filterState（搜索、筛选等）变化时对 MainView 的触发重建。
//

import SwiftUI

/// 主内容区域：持有 filterState、detailState，渲染 NavigationSplitView
/// 当 filterState/detailState 变更时仅此视图及其子树重建，MainView 不重建
struct MainContentArea: View {
    let interfaceLayoutStyle: InterfaceLayoutStyle

    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @StateObject private var filterState = ResourceFilterState()
    @StateObject private var detailState = ResourceDetailState()
    @EnvironmentObject var gameRepository: GameRepository
    @Environment(\.appLogger)
    private var logger

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 168, ideal: 168, max: 168)
        } content: {
            if interfaceLayoutStyle == .classic {
                middleColumnContentView
            } else {
                middleColumnDetailView
            }
        } detail: {
            if interfaceLayoutStyle == .classic {
                middleColumnDetailView
            } else {
                middleColumnContentView
            }
        }
        .environmentObject(filterState)
        .environmentObject(detailState)
        .onChange(of: detailState.selectedItem) { oldValue, newValue in
            handleSidebarItemChange(from: oldValue, to: newValue)
        }
        .onChange(of: gameRepository.workingPathChanged) { _, _ in
            detailState.selectedItem = .resource(.mod)
            detailState.gameType = true
            scanAllGamesModsDirectory()
        }
    }

    @ViewBuilder private var middleColumnDetailView: some View {
        DetailView()
            .toolbar {
                DetailToolbarView()
            }
    }

    @ViewBuilder private var middleColumnContentView: some View {
        ContentView()
            .toolbar { ContentToolbarView() }
            .navigationSplitViewColumnWidth(min: 235, ideal: 235, max: 280)
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

    private func handleResourceToGameTransition(gameId: String) {
        if detailState.gameId != nil, detailState.selectedProjectId == nil {
            filterState.clearSearchText()
        }
        if detailState.gameType == true && detailState.gameId == nil {
            filterState.clearSearchText()
            detailState.gameType = false
        }

        let game = gameRepository.getGame(by: gameId)
        if let loader = game?.modLoader.lowercased() {
            let currentType = detailState.gameResourcesType.lowercased()
            if loader == "vanilla" {
                if currentType == "mod" || currentType == "shader" || currentType == "modpack" {
                    detailState.gameResourcesType = "datapack"
                }
            } else {
                if detailState.selectedProjectId == nil {
                    detailState.gameResourcesType = "mod"
                }
            }
        }

        detailState.gameId = gameId
        detailState.selectedProjectId = nil
        SelectedGameManager.shared.setSelectedGame(gameId)
    }

    private func handleGameToGameTransition(
        from oldId: String,
        to newId: String
    ) {
        filterState.clearSearchText()
        detailState.gameType = false

        let game = gameRepository.getGame(by: newId)
        if let loader = game?.modLoader.lowercased() {
            detailState.gameResourcesType = (loader == "vanilla") ? "datapack" : "mod"
        }
        detailState.gameId = newId
        SelectedGameManager.shared.setSelectedGame(newId)
    }

    private func resetToResourceDefaults() {
        if case .resource = detailState.selectedItem {
            if detailState.gameId == nil {
                filterState.clearSearchText()
            }
        }
        SelectedGameManager.shared.clearSelection()

        if !detailState.gameType && detailState.selectedProjectId == nil {
            detailState.gameType = true
        }
        filterState.sortIndex = AppConstants.modrinthIndex

        if case .resource(let resourceType) = detailState.selectedItem {
            detailState.gameResourcesType = resourceType.rawValue
        }
        filterState.clearFiltersAndPagination()

        if detailState.gameId == nil && detailState.selectedProjectId != nil {
            detailState.selectedProjectId = nil
        }
        if detailState.selectedProjectId == nil && detailState.gameId != nil {
            detailState.gameId = nil
            filterState.clearSearchText()
        }
        if detailState.loadedProjectDetail != nil && detailState.gameId != nil
            && detailState.selectedProjectId != nil {
            detailState.gameId = nil
            detailState.loadedProjectDetail = nil
            detailState.selectedProjectId = nil
        }
    }

    private func scanAllGamesModsDirectory() {
        Task {
            let games = gameRepository.games
            logger.info("开始扫描 \(games.count) 个游戏的 mods 目录")
            await withTaskGroup(of: Void.self) { group in
                for game in games {
                    group.addTask {
                        await ModScanner.shared.scanGameModsDirectory(game: game)
                    }
                }
            }
            logger.info("完成所有游戏的 mods 目录扫描")
        }
    }
}
