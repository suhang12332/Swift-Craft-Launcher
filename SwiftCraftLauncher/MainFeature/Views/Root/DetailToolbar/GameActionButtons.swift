//
//  GameActionButtons.swift
//  SwiftCraftLauncher
//

import SwiftUI
import AppKit

/// 详情工具栏中与当前游戏相关的操作按钮（启动/停止、设置、在访达中显示、导出、删除）
struct GameActionButtons: View {
    let game: GameVersionInfo
    @Environment(\.controlActiveState)
    private var controlActiveState

    @Environment(\.openSettings)
    private var openSettings
    @EnvironmentObject var detailState: ResourceDetailState
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var gameLaunchUseCase: GameLaunchUseCase
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @ObservedObject private var selectedGameManager = SelectedGameManager.shared
    @StateObject private var gameStatusManager = GameStatusManager.shared
    @StateObject private var gameActionManager = GameActionManager.shared
    @State private var showDeleteAlert = false
    @State private var showExportSheet = false
    @State private var showCrashAlert = false
    @State private var crashDirectory: URL?

    private func isGameRunning(gameId: String, userId: String) -> Bool {
        gameStatusManager.isGameRunning(gameId: gameId, userId: userId)
    }

    var body: some View {
        Group {
            Button {
                Task {
                    let userId = playerListViewModel.currentPlayer?.id ?? ""
                    let isRunning = isGameRunning(gameId: game.id, userId: userId)
                    if isRunning {
                        await gameLaunchUseCase.stopGame(player: playerListViewModel.currentPlayer, game: game)
                    } else {
                        gameStatusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: true)
                        defer { gameStatusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: false) }
                        await gameLaunchUseCase.launchGame(
                            player: playerListViewModel.currentPlayer,
                            game: game
                        )
                    }
                }
            } label: {
                let userId = playerListViewModel.currentPlayer?.id ?? ""
                let isRunning = isGameRunning(gameId: game.id, userId: userId)
                let isLaunchingGame = gameStatusManager.isGameLaunching(gameId: game.id, userId: userId)
                if isLaunchingGame && !isRunning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label(
                        isRunning
                        ? "stop.fill".localized()
                        : "play.fill".localized(),
                        systemImage: isRunning
                        ? "stop.fill" : "play.fill"
                    )
                }
            }
            .id(controlActiveState)
            .help(
                isGameRunning(gameId: game.id, userId: playerListViewModel.currentPlayer?.id ?? "")
                ? "stop.fill"
                : (gameStatusManager.isGameLaunching(gameId: game.id, userId: playerListViewModel.currentPlayer?.id ?? "") ? "" : "play.fill")
            )
            .disabled(gameStatusManager.isGameLaunching(gameId: game.id, userId: playerListViewModel.currentPlayer?.id ?? ""))
            .applyReplaceTransition()

            Button {
                selectedGameManager.setSelectedGameAndOpenAdvancedSettings(game.id)
                openSettings()
            } label: {
                Label(
                    "settings.game.advanced.tab".localized(),
                    systemImage: "gearshape"
                )
            }
            .id(controlActiveState)
            .help("settings.game.advanced.tab".localized())

            Button {
                gameActionManager.showInFinder(game: game)
            } label: {
                Label("game.path".localized(), systemImage: "folder")
            }
            .id(controlActiveState)
            .help("game.path".localized())

            Button {
                showExportSheet = true
            } label: {
                Label("modpack.export.button".localized(), systemImage: "square.and.arrow.up")
            }
            .help("modpack.export.button".localized())
            .sheet(isPresented: $showExportSheet) {
                ModPackExportSheet(gameInfo: game)
            }

            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("sidebar.context_menu.delete_game".localized(), systemImage: "trash")
            }
            .help("sidebar.context_menu.delete_game".localized())
            .confirmationDialog(
                "delete.title".localized(),
                isPresented: $showDeleteAlert,
                titleVisibility: .visible
            ) {
                Button("common.delete".localized(), role: .destructive) {
                    gameActionManager.deleteGame(
                        game: game,
                        gameRepository: gameRepository,
                        selectedItem: detailState.selectedItemBinding,
                        gameType: detailState.gameTypeBinding
                    )
                }
                .keyboardShortcut(.defaultAction)
                Button("common.cancel".localized(), role: .cancel) {}
            } message: {
                Text(
                    String(format: "delete.game.confirm".localized(), game.gameName)
                )
            }
            .alert(
                "error.game_launch.game_crashed".localized(),
                isPresented: $showCrashAlert
            ) {
                Button("menu.open.log".localized()) {
                    if let directory = crashDirectory {
                        NSWorkspace.shared.open(directory)
                    } else {
                        Logger.shared.error("无法打开游戏目录：directory 为空")
                    }
                }
                Button("common.close".localized(), role: .cancel) {}
            } message: {
                Text("error.game_launch.game_crashed.description".localized())
            }
            .onReceive(NotificationCenter.default.publisher(for: .gameCrashed)) { notification in
                let directory = notification.userInfo?["directory"] as? URL
                crashDirectory = directory
                showCrashAlert = true
            }
        }
    }
}
