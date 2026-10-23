//
//  ContentView.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI
import WebKit

/// Primary content view that displays game or resource details based on the selected item.
struct ContentView: View {
    @Environment(ResourceFilterState.self)
    private var filterState
    @Environment(ResourceDetailState.self)
    private var detailState
    @Environment(GameRepository.self)
    private var gameRepository
    @Environment(PlayerListViewModel.self)
    private var playerListViewModel

    var body: some View {
        List {
            switch detailState.selectedItem {
            case let .game(gameId):
                gameContentView(gameId: gameId)
            case let .resource(type):
                resourceContentView(type: type)
            }
        }
    }

    @ViewBuilder
    private func gameContentView(gameId: String) -> some View {
        if let game = gameRepository.getGame(by: gameId) {
            if detailState.gameType {
                serverModeView(game: game)
            } else {
                localModeView(game: game, gameId: gameId)
            }
        }
    }

    private func serverModeView(game: GameVersionInfo) -> some View {
        @Bindable var filterState = filterState
        return CategoryContentView(
            project: detailState.gameResourcesType,
            type: "game",
            selectedCategories: $filterState.selectedCategories,
            selectedFeatures: $filterState.selectedFeatures,
            selectedResolutions: $filterState.selectedResolutions,
            selectedPerformanceImpacts: $filterState.selectedPerformanceImpact,
            selectedVersions: $filterState.selectedVersions,
            selectedLoaders: $filterState.selectedLoaders,
            gameVersion: game.gameVersion,
            gameLoader: game.modLoader.lowercased() == GameLoader.vanilla.displayName ? nil : game.modLoader,
            dataSource: filterState.dataSource,
        )
        .id(detailState.gameResourcesType)
    }

    private func localModeView(game: GameVersionInfo, gameId: String) -> some View {
        SaveInfoView(gameId: gameId, gameName: game.gameName, modLoader: game.modLoader)
            .id(gameId)
    }

    @ViewBuilder
    private func resourceContentView(type: ResourceType) -> some View {
        @Bindable var filterState = filterState
        @Bindable var detailState = detailState
        if let projectId = detailState.selectedProjectId {
            ModrinthProjectContentView(
                projectDetail: $detailState.loadedProjectDetail,
                projectId: projectId,
                resourceType: type.rawValue,
            )
        } else {
            CategoryContentView(
                project: type.rawValue,
                type: "resource",
                selectedCategories: $filterState.selectedCategories,
                selectedFeatures: $filterState.selectedFeatures,
                selectedResolutions: $filterState.selectedResolutions,
                selectedPerformanceImpacts: $filterState.selectedPerformanceImpact,
                selectedVersions: $filterState.selectedVersions,
                selectedLoaders: $filterState.selectedLoaders,
                dataSource: filterState.dataSource,
            )
            .id(type)
        }
    }
}
