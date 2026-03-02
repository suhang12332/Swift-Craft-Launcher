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
        contentView
            .sheet(isPresented: detailState.showInstallSheetBinding) {
                if let project = detailState.currentProject,
                   let detail = detailState.loadedProjectDetail {
                    if detailState.gameResourcesType == "modpack" {
                        ModPackDownloadSheet(
                            projectId: project.projectId,
                            gameInfo: nil,
                            query: detailState.gameResourcesType,
                            preloadedDetail: detail
                        )
                        .environmentObject(gameRepository)
                    } else {
                        GlobalResourceSheet(
                            project: project,
                            resourceType: detailState.gameResourcesType,
                            isPresented: detailState.showInstallSheetBinding,
                            preloadedDetail: detail,
                            preloadedCompatibleGames: detailState.compatibleGames
                        )
                        .environmentObject(gameRepository)
                    }
                }
            }
            .onChange(of: detailState.showInstallSheet) { _, newValue in
                if !newValue {
                    detailState.compatibleGames = []
                }
            }
    }

    @ViewBuilder
    private var contentView: some View {
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
        if detailState.selectedProjectId != nil {
            List {
                ModrinthProjectDetailView(
                    projectDetail: detailState.loadedProjectDetail
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
                searchText: filterState.searchTextBinding
            )
        }
    }
}
