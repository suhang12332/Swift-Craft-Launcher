//
//  MainView.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Root navigation view that orchestrates the sidebar, content, and detail columns.
struct MainView: View {
    @Environment(DIContainer.self)
    private var container
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var filterState = ResourceFilterState()
    @State private var detailState = ResourceDetailState()
    @Environment(GameRepository.self)
    private var gameRepository

    @Environment(PlayerListViewModel.self)
    private var playerListViewModel

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 168, ideal: 200, max: 260)
        } content: {
            if container.ui.generalSettingsManager.interfaceLayoutStyle == .classic {
                middleColumnContentView
            } else {
                middleColumnDetailView
            }
        } detail: {
            if container.ui.generalSettingsManager.interfaceLayoutStyle == .classic {
                middleColumnDetailView
            } else {
                middleColumnContentView
            }
        }
        .environment(filterState)
        .environment(detailState)
        .sheet(
            isPresented: Binding(
                get: { container.ui.openURLModPackImportPresenter.showImportSheet },
                set: { container.ui.openURLModPackImportPresenter.showImportSheet = $0 },
            ),
            onDismiss: { container.ui.openURLModPackImportPresenter.clear() },
            content: {
                if let file = container.ui.openURLModPackImportPresenter.preselectedTempFile {
                    GameFormView(initialMode: GameFormMode.modPackImport(file: file, shouldProcess: true))
                        .presentationBackgroundInteraction(.automatic)
                }
            },
        )
        .onChange(of: detailState.selectedItem) { oldValue, newValue in
            handleSidebarItemChange(from: oldValue, to: newValue)
        }
        .onChange(of: container.core.selectedGameManager.selectedGameId) { _, newId in
            guard let gameId = newId else { return }
            if case .game(gameId) = detailState.selectedItem {
                return
            }
            detailState.selectedItem = .game(gameId)
        }
        .onChange(of: gameRepository.workingPathChanged) { _, _ in
            detailState.selectedItem = .resource(.mod)
            detailState.gameType = true
        }
        .task {
            await loadInitialAppData()
        }
        .mainViewPresentations(container: container, detailState: detailState)
        .frame(minWidth: 900, minHeight: 500)
    }

    private var middleColumnDetailView: some View {
        DetailView()
            .environment(container.core.favoriteStore)
            .toolbar {
                DetailToolbarView()
            }
    }

    private var middleColumnContentView: some View {
        ContentView()
            .toolbar { ContentToolbarView() }
            .navigationSplitViewColumnWidth(min: 235, ideal: 235, max: 280)
    }

    private func handleSidebarItemChange(
        from oldValue: SidebarItem,
        to newValue: SidebarItem,
    ) {
        switch (oldValue, newValue) {
        case let (.resource, .game(id)):
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
        if detailState.gameType == true, detailState.gameId == nil {
            filterState.clearSearchText()
            detailState.gameType = false
        }

        let game = gameRepository.getGame(by: gameId)
        if let loader = game?.modLoader.lowercased() {
            let currentType = detailState.gameResourcesType.lowercased()
            if loader == GameLoader.vanilla.displayName {
                let modifiableTypes: [String] = [
                    ResourceType.mod.rawValue,
                    ResourceType.shader.rawValue,
                    ResourceType.modpack.rawValue,
                    ResourceType.minecraftJavaServer.rawValue,
                ]
                if modifiableTypes.contains(currentType) {
                    detailState.gameResourcesType = ResourceType.datapack.rawValue
                }
            } else {
                if detailState.selectedProjectId == nil {
                    detailState.gameResourcesType = ResourceType.mod.rawValue
                }
                if detailState.selectedProjectId != nil, detailState.gameResourcesType == ResourceType.minecraftJavaServer.rawValue {
                    detailState.gameResourcesType = ResourceType.mod.rawValue
                }
                if gameId != detailState.gameId {
                    detailState.gameResourcesType = ResourceType.mod.rawValue
                    detailState.gameType = false
                }
            }
        }

        detailState.gameId = gameId
        detailState.selectedProjectId = nil
        container.core.selectedGameManager.setSelectedGame(gameId)
    }

    private func handleGameToGameTransition(
        from _: String,
        to newId: String,
    ) {
        filterState.clearSearchText()
        detailState.gameType = false

        let game = gameRepository.getGame(by: newId)
        if let loader = game?.modLoader.lowercased() {
            detailState.gameResourcesType = (loader == GameLoader.vanilla.displayName) ? ResourceType.datapack.rawValue : ResourceType.mod.rawValue
        }
        detailState.gameId = newId
        container.core.selectedGameManager.setSelectedGame(newId)
    }

    private func resetToResourceDefaults() {
        if case .resource = detailState.selectedItem {
            if detailState.gameId == nil {
                filterState.clearSearchText()
            }
        }
        container.core.selectedGameManager.clearSelection()

        if !detailState.gameType, detailState.selectedProjectId == nil {
            detailState.gameType = true
        }
        filterState.sortIndex = AppConstants.modrinthIndex

        if case let .resource(resourceType) = detailState.selectedItem {
            detailState.gameResourcesType = resourceType.rawValue
        }
        filterState.clearFiltersAndPagination()

        if detailState.gameId == nil, detailState.selectedProjectId != nil {
            detailState.selectedProjectId = nil
        }
        if detailState.selectedProjectId == nil, detailState.gameId != nil {
            detailState.gameId = nil
            filterState.clearSearchText()
        }
        if detailState.loadedProjectDetail != nil, detailState.gameId != nil,
           detailState.selectedProjectId != nil {
            detailState.gameId = nil
            detailState.loadedProjectDetail = nil
            detailState.selectedProjectId = nil
        }
        if !detailState.gameType, detailState.selectedProjectId == nil {
            detailState.gameType = true
        }
        if detailState.gameResourcesType == ResourceType.minecraftJavaServer.rawValue {
            filterState.dataSource = .modrinth
        }
    }

    @MainActor
    private func loadInitialAppData() async {
        playerListViewModel.loadPlayersIfNeeded()
        await gameRepository.loadInitialDataIfNeeded()

        if let firstGame = gameRepository.games.first {
            detailState.selectedItem = .game(firstGame.id)
        }
    }
}
