//
//  DetailView.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays detailed information for the selected game or resource item.
struct DetailView: View {
    @Environment(ResourceFilterState.self)
    private var filterState
    @Environment(ResourceDetailState.self)
    private var detailState
    @Environment(GameRepository.self)
    private var gameRepository

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
        @Bindable var filterState = filterState
        @Bindable var detailState = detailState
        if let gameInfo = gameRepository.getGame(by: gameId) {
            GameInfoDetailView(
                game: gameInfo,
                query: detailState.gameResourcesType,
                dataSource: filterState.dataSource,
                selectedVersions: filterState.selectedVersions,
                selectedCategories: filterState.selectedCategories,
                selectedFeatures: filterState.selectedFeatures,
                selectedResolutions: filterState.selectedResolutions,
                selectedPerformanceImpact: filterState.selectedPerformanceImpact,
                selectedProjectId: $detailState.selectedProjectId,
                selectedLoaders: filterState.selectedLoaders,
                gameType: detailState.gameType,
                selectedItem: $detailState.selectedItem,
                searchText: $filterState.searchText,
                localResourceFilter: filterState.localResourceFilter,
            )
        }
    }

    @ViewBuilder
    private func resourceDetailView(type: ResourceType) -> some View {
        @Bindable var filterState = filterState
        @Bindable var detailState = detailState
        if detailState.selectedProjectId != nil {
            List {
                ModrinthProjectDetailView(
                    projectDetail: detailState.loadedProjectDetail,
                )
            }
        } else {
            ModrinthDetailView(
                query: type.rawValue,
                selectedVersions: filterState.selectedVersions,
                selectedCategories: filterState.selectedCategories,
                selectedFeatures: filterState.selectedFeatures,
                selectedResolutions: filterState.selectedResolutions,
                selectedPerformanceImpact: filterState.selectedPerformanceImpact,
                selectedProjectId: $detailState.selectedProjectId,
                selectedLoader: filterState.selectedLoaders,
                gameInfo: nil,
                selectedItem: $detailState.selectedItem,
                gameType: detailState.gameType,
                dataSource: filterState.dataSource,
                searchText: $filterState.searchText,
            )
        }
    }
}
