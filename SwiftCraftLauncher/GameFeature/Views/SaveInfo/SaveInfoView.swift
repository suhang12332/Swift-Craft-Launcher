//
//  SaveInfoView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// Main view displaying save information including worlds, screenshots, servers, and schematics.
import SwiftUI

struct SaveInfoView: View {
    let gameId: String
    let gameName: String
    @StateObject private var manager: SaveInfoManager
    @EnvironmentObject private var gameStatusManager: GameStatusManager

    @EnvironmentObject private var playerListViewModel: PlayerListViewModel

    init(
        gameId: String,
        gameName: String,
    ) {
        self.gameId = gameId
        self.gameName = gameName
        _manager = StateObject(wrappedValue: SaveInfoManager(gameName: gameName))
    }

    private var currentGameRunningState: Bool {
        let userId = playerListViewModel.currentPlayer?.id ?? ""
        let key = GameProcessManager.processKey(gameId: gameId, userId: userId)
        if let isRunning = gameStatusManager.allGameStates[key] {
            return isRunning
        } else {
            return false
        }
    }

    var body: some View {
        VStack {
            if manager.hasWorldsType {
                WorldInfoSectionView(
                    worlds: manager.worlds,
                    isLoading: manager.isLoadingWorlds,
                    gameName: gameName,
                )
            }

            if manager.hasScreenshotsType {
                ScreenshotSectionView(
                    screenshots: manager.screenshots,
                    isLoading: manager.isLoadingScreenshots,
                    gameName: gameName,
                )
            }

            ServerAddressSectionView(
                servers: manager.servers,
                isLoading: manager.isLoadingServers,
                gameName: gameName,
            ) {
                Task {
                    await manager.loadData()
                }
            }

            if manager.hasLitematicaType {
                LitematicaSectionView(
                    litematicaFiles: manager.litematicaFiles,
                    isLoading: manager.isLoadingLitematica,
                    gameName: gameName,
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
        .onChange(of: currentGameRunningState) { oldValue, newValue in
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
