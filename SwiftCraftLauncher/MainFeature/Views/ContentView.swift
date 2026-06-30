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
    @EnvironmentObject private var filterState: ResourceFilterState
    @EnvironmentObject private var detailState: ResourceDetailState
    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel

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
        CategoryContentView(
            project: detailState.gameResourcesType,
            type: "game",
            selectedCategories: filterState.selectedCategoriesBinding,
            selectedFeatures: filterState.selectedFeaturesBinding,
            selectedResolutions: filterState.selectedResolutionsBinding,
            selectedPerformanceImpacts: filterState.selectedPerformanceImpactBinding,
            selectedVersions: filterState.selectedVersionsBinding,
            selectedLoaders: filterState.selectedLoadersBinding,
            gameVersion: game.gameVersion,
            gameLoader: game.modLoader.lowercased() == GameLoader.vanilla.displayName ? nil : game.modLoader,
            dataSource: filterState.dataSource,
        )
        .id(detailState.gameResourcesType)
    }

    private func localModeView(game: GameVersionInfo, gameId: String) -> some View {
        SaveInfoView(gameId: gameId, gameName: game.gameName)
            .id(gameId)
    }

    @ViewBuilder
    private func resourceContentView(type: ResourceType) -> some View {
        if let projectId = detailState.selectedProjectId {
            ModrinthProjectContentView(
                projectDetail: detailState.loadedProjectDetailBinding,
                projectId: projectId,
                resourceType: type.rawValue,
            )
        } else {
            CategoryContentView(
                project: type.rawValue,
                type: "resource",
                selectedCategories: filterState.selectedCategoriesBinding,
                selectedFeatures: filterState.selectedFeaturesBinding,
                selectedResolutions: filterState.selectedResolutionsBinding,
                selectedPerformanceImpacts: filterState.selectedPerformanceImpactBinding,
                selectedVersions: filterState.selectedVersionsBinding,
                selectedLoaders: filterState.selectedLoadersBinding,
                dataSource: filterState.dataSource,
            )
            .id(type)
        }
    }
}
