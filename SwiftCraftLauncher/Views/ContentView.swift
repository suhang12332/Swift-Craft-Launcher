//
//  ContentView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/1.
//

import SwiftUI
import WebKit

struct ContentView: View {
    // MARK: - Properties
    let selectedItem: SidebarItem
    @Binding var selectedVersions: [String]
    @Binding var selectedLicenses: [String]
    @Binding var selectedCategories: [String]
    @Binding var selectedFeatures: [String]
    @Binding var selectedResolutions: [String]
    @Binding var selectedPerformanceImpact: [String]
    @Binding var selectProjectId: String?
    @Binding var loadedProjectDetail: ModrinthProjectDetail?
    @Binding var gameResourcesType: String
    @Binding var selectedLoaders: [String]
    @Binding var gameType: Bool
    @Binding var gameId: String?
    
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    
    // MARK: - Body
    var body: some View {
        List {
            switch selectedItem {
            case .game(let gameId):
                gameContentView(gameId: gameId)
            case .resource(let type):
                resourceContentView(type: type)
            }
        }
    }
    
    // MARK: - Game Content View
    @ViewBuilder
    private func gameContentView(gameId: String) -> some View {
        if let game = gameRepository.getGame(by: gameId) {
            if gameType {
                serverModeView(game: game)
            } else {
                localModeView(game: game)
            }
        }
    }
    
    private func serverModeView(game: GameVersionInfo) -> some View {
        CategoryContentView(
            project: gameResourcesType,
            type: "game",
            selectedCategories: $selectedCategories,
            selectedFeatures: $selectedFeatures,
            selectedResolutions: $selectedResolutions,
            selectedPerformanceImpacts: $selectedPerformanceImpact,
            selectedVersions: $selectedVersions,
            selectedLoaders: $selectedLoaders,
            gameVersion: game.gameVersion,
            gameLoader: game.modLoader == "Vanilla" ? nil : game.modLoader
        )
        .id(gameResourcesType)
    }
    
    private func localModeView(game: GameVersionInfo) -> some View {
        // TODO: Implement local mode view
//         HStack {
//             MinecraftSkinRenderView(
//                 skinName: playerListViewModel.currentPlayer?.avatarName
//             ).frame(minWidth: 200, minHeight: 400)
//         }
        Label("development.in_progress".localized(), systemImage: "figure.outdoor.soccer")
    }
    
    // MARK: - Resource Content View
    @ViewBuilder
    private func resourceContentView(type: ResourceType) -> some View {
        if let projectId = selectProjectId {
            ModrinthProjectContentView(
                projectDetail: $loadedProjectDetail,
                projectId: projectId
            )
        } else {
            CategoryContentView(
                project: type.rawValue,
                type: "resource",
                selectedCategories: $selectedCategories,
                selectedFeatures: $selectedFeatures,
                selectedResolutions: $selectedResolutions,
                selectedPerformanceImpacts: $selectedPerformanceImpact,
                selectedVersions: $selectedVersions,
                selectedLoaders: $selectedLoaders
            )
            .id(type)
        }
    }
}
