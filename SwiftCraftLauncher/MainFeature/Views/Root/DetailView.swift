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
    @State private var isResourceTransitioning = false
    @State private var transitionTask: Task<Void, Never>?

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
            ZStack(alignment: .leading) {
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
                .frame(width: width, height: proxy.size.height)
                // 列表层保持基本静止，仅做轻微位移来保留“左滑切换”感
                .offset(x: showDetail ? -24 : 0)
                .opacity(showDetail ? 0.96 : 1.0)

                List {
                    ModrinthProjectDetailView(
                        projectDetail: detailState.loadedProjectDetail,
                        suppressAnimations: isResourceTransitioning
                    )
                }
                .frame(width: width, height: proxy.size.height)
                .offset(x: showDetail ? 0 : width)
                .allowsHitTesting(showDetail)
            }
            .clipped()
            .animation(.easeOut(duration: 0.2), value: showDetail)
            .onChange(of: showDetail) { _, _ in
                transitionTask?.cancel()
                isResourceTransitioning = true
                transitionTask = Task {
                    try? await Task.sleep(nanoseconds: 260_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        isResourceTransitioning = false
                    }
                }
            }
        }
    }
}
