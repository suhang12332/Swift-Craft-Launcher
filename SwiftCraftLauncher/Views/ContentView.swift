//
//  ContentView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/1.
//

import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject var filterState: ResourceFilterState
    @EnvironmentObject var detailState: ResourceDetailState
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var playerListViewModel: PlayerListViewModel

    var body: some View {
        List {
            switch detailState.selectedItem {
            case .game(let gameId):
                gameContentView(gameId: gameId)
            case .resource(let type):
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
            gameLoader: game.modLoader == "Vanilla" ? nil : game.modLoader,
            dataSource: filterState.dataSource
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
                projectId: projectId
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
                dataSource: filterState.dataSource
            )
            .id(type)
        }
    }
}
