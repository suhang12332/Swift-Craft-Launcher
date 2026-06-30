//
//  DetailView.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays detailed information for the selected game or resource item.
struct DetailView: View {
    @EnvironmentObject private var filterState: ResourceFilterState
    @EnvironmentObject private var detailState: ResourceDetailState
    @EnvironmentObject private var gameRepository: GameRepository

    var body: some View {
        Group {
            switch detailState.selectedItem {
            case let .game(gameId):
                gameDetailView(gameId: gameId)
            case let .resource(type):
                resourceDetailView(type: type)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func gameDetailView(gameId: String) -> some View {
        if let gameInfo = gameRepository.getGame(by: gameId) {
            GameInfoDetailView(
                game: gameInfo,
                query: detailState.gameResourcesTypeBinding,
                dataSource: filterState.dataSourceBinding,
                selectedVersions: filterState.selectedVersionsBinding,
                selectedCategories: filterState.selectedCategoriesBinding,
                selectedFeatures: filterState.selectedFeaturesBinding,
                selectedResolutions: filterState.selectedResolutionsBinding,
                selectedPerformanceImpact: filterState.selectedPerformanceImpactBinding,
                selectedProjectId: detailState.selectedProjectIdBinding,
                selectedLoaders: filterState.selectedLoadersBinding,
                gameType: detailState.gameTypeBinding,
                selectedItem: detailState.selectedItemBinding,
                searchText: filterState.searchTextBinding,
                localResourceFilter: filterState.localResourceFilterBinding,
            )
        }
    }

    @ViewBuilder
    private func resourceDetailView(type: ResourceType) -> some View {
        if detailState.selectedProjectId != nil {
            List {
                ModrinthProjectDetailView(
                    projectDetail: detailState.loadedProjectDetail,
                )
            }
        } else {
            ModrinthDetailView(
                query: type.rawValue,
                selectedVersions: filterState.selectedVersionsBinding,
                selectedCategories: filterState.selectedCategoriesBinding,
                selectedFeatures: filterState.selectedFeaturesBinding,
                selectedResolutions: filterState.selectedResolutionsBinding,
                selectedPerformanceImpact: filterState.selectedPerformanceImpactBinding,
                selectedProjectId: detailState.selectedProjectIdBinding,
                selectedLoader: filterState.selectedLoadersBinding,
                gameInfo: nil,
                selectedItem: detailState.selectedItemBinding,
                gameType: detailState.gameTypeBinding,
                dataSource: filterState.dataSourceBinding,
                searchText: filterState.searchTextBinding,
            )
        }
    }
}
