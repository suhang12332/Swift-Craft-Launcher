//
//  DetailView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/1.
//

import SwiftUI

struct DetailView: View {
    @EnvironmentObject var filterState: ResourceFilterState
    @EnvironmentObject var detailState: ResourceDetailState
    @EnvironmentObject var gameRepository: GameRepository

    @ViewBuilder var body: some View {
        switch detailState.selectedItem {
        case .game(let gameId):
            gameDetailView(gameId: gameId).frame(maxWidth: .infinity, alignment: .leading)
        case .resource(let type):
            resourceDetailView(type: type)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                localResourceFilter: filterState.localResourceFilterBinding
            )
        }
    }

    @ViewBuilder
    private func resourceDetailView(type: ResourceType) -> some View {
        GeometryReader { proxy in
            let showDetail = detailState.selectedProjectId != nil
            let width = proxy.size.width

            ZStack {
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
                    searchText: filterState.searchTextBinding
                )
                .offset(x: showDetail ? -width : 0)
                .opacity(showDetail ? 0.92 : 1.0)
                .allowsHitTesting(!showDetail)
                .zIndex(0)

                List {
                    ModrinthProjectDetailView(
                        projectDetail: detailState.loadedProjectDetail
                    )
                }
                .offset(x: showDetail ? 0 : width)
                .opacity(showDetail ? 1.0 : 0.0)
                .allowsHitTesting(showDetail)
                .zIndex(1)
            }
            .clipped()
            .animation(.easeInOut(duration: 0.28), value: showDetail)
        }
    }
}
