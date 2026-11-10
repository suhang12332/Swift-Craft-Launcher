//
//  SaveInfoView.swift
//  GameFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

// Main view displaying save information including worlds, screenshots, and schematics.
import SwiftUI

struct SaveInfoView: View {
    let gameId: String
    let gameName: String
    let modLoader: String
    @State private var manager: SaveInfoManager
    @Environment(DIContainer.self)
    private var container
    @Environment(PlayerListViewModel.self)
    private var playerListViewModel

    init(
        gameId: String,
        gameName: String,
        modLoader: String,
    ) {
        self.gameId = gameId
        self.gameName = gameName
        self.modLoader = modLoader
        _manager = State(wrappedValue: SaveInfoManager(gameName: gameName, modLoader: modLoader))
    }

    private var gameState: GameRuntimeState {
        GameRuntimeState(
            gameId: gameId,
            userId: playerListViewModel.currentPlayer?.id,
            sessionStore: container.core.gameSessionStore,
        )
    }

    var body: some View {
        VStack {
            ResourceCountSectionView(counts: manager.resourceCounts)
            if manager.hasWorldsType {
                WorldInfoSectionView(
                    worlds: manager.worlds,
                    isLoading: manager.isLoadingWorlds,
                )
            }

            if manager.hasScreenshotsType {
                ScreenshotSectionView(
                    screenshots: manager.screenshots,
                    isLoading: manager.isLoadingScreenshots,
                    gameName: gameName,
                )
            }

            if manager.hasLitematicaType {
                LitematicaSectionView(
                    litematicaFiles: manager.litematicaFiles,
                    isLoading: manager.isLoadingLitematica,
                )
            }

            if manager.hasLogsType {
                LogSectionView(
                    logs: manager.logs,
                    isLoading: manager.isLoadingLogs,
                )
            }
        }
        .onChange(of: gameId) { _, _ in
            Task {
                await manager.loadData()
            }
        }
        .task {
            await manager.loadData()
        }
        .onChange(of: gameState.isRunning) { oldValue, newValue in
            if oldValue == true, newValue == false {
                Task {
                    await manager.loadData()
                }
            }
        }
        .onDisappear {
            manager.clearCache()
        }
    }
}
