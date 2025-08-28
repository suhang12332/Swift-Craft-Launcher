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
    @Binding var showAdvancedSettings: Bool

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
        .onChange(of: selectedItem) { _, _ in
            // 切换游戏时重置高级设置状态
            showAdvancedSettings = false
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
        Group {
            if !hasSaves(for: game.gameName) || showAdvancedSettings {
                // 没有存档时默认显示设置，或者点击了设置按钮时显示设置
                GameAdvancedSettingsView(game: game)
            } else {
                // 有存档且没有点击设置按钮时显示存档信息
                ProfilesView(gameName: game.gameName)
            }
        }
        .id(gameId)
    }

    private func hasSaves(for gameName: String) -> Bool {
        let savesDir = AppPaths.savesDirectory(gameName: gameName)

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: savesDir,
                includingPropertiesForKeys: nil
            )
            return !contents.isEmpty
        } catch {
            return false
        }
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
