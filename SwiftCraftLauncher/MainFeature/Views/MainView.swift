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
    var container
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var filterState = ResourceFilterState()
    @State private var detailState = ResourceDetailState()
    @State private var navigationHandler: SidebarNavigationHandler?
    @Environment(GameRepository.self)
    private var gameRepository

    @Environment(PlayerListViewModel.self)
    private var playerListViewModel

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 168, ideal: 200, max: 260)
        } content: {
            contentView
        } detail: {
            detailView
        }
        .environment(filterState)
        .environment(container.ui.translationManager)
        .environment(detailState)
        .modPackImportSheet()
        .onChange(of: detailState.selectedItem) { oldValue, newValue in
            navigationHandler?.handleSidebarItemChange(from: oldValue, to: newValue)
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
            navigationHandler = SidebarNavigationHandler(
                filterState: filterState,
                detailState: detailState,
                gameRepository: gameRepository,
                container: container,
            )
            await loadInitialAppData()
        }
        .mainViewPresentations(container: container, detailState: detailState)
        .frame(minWidth: 900, minHeight: 500)
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
