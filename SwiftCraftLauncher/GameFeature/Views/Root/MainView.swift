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
    @StateObject private var filterState = ResourceFilterState()
    @StateObject private var detailState = ResourceDetailState()
    @StateObject private var general = GeneralSettingsManager.shared
    @StateObject private var selectedGameManager = SelectedGameManager.shared
    @EnvironmentObject var gameRepository: GameRepository
    @Environment(\.appLogger)
    private var logger

    // MARK: - Body
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 168, ideal: 168, max: 168)
        } content: {
            if general.interfaceLayoutStyle == .classic {
                middleColumnContentView
            } else {
                middleColumnDetailView
            }
        } detail: {
            if general.interfaceLayoutStyle == .classic {
                middleColumnDetailView
            } else {
                middleColumnContentView
            }
        }
        .environmentObject(filterState)
        .environmentObject(detailState)
        .frame(minWidth: 900, minHeight: 500)
        .onChange(of: detailState.selectedItem) { oldValue, newValue in
            handleSidebarItemChange(from: oldValue, to: newValue)
        }
        .onChange(of: gameRepository.workingPathChanged) { _, _ in
            detailState.selectedItem = .resource(.mod)
            detailState.gameType = true
            scanAllGamesModsDirectory()
        }
    }

    // MARK: - Content / Detail Column Views（供对调配置使用）

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

    // MARK: - Transition Helpers
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
        selectedGameManager.setSelectedGame(gameId)
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
        selectedGameManager.setSelectedGame(newId)
    }

    // MARK: - Resource Reset
    private func resetToResourceDefaults() {
        if case .resource = detailState.selectedItem {
            if detailState.gameId == nil {
                filterState.clearSearchText()
            }
        }
        selectedGameManager.clearSelection()

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

    // MARK: - Scanning Methods
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
