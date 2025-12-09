//
//  GameHubView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/28.
//

import SwiftUI

/// 游戏中心视图 - 类似 Apple Games 的布局
struct GameHubView: View {
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @StateObject private var gameStatusManager = GameStatusManager.shared
    @StateObject private var gameActionManager = GameActionManager.shared
    
    @State private var selectedGame: GameVersionInfo?
    @State private var currentBannerIndex: Int = 0
    
    // 最近玩的游戏（按最后游玩时间排序）
    private var recentGames: [GameVersionInfo] {
        gameRepository.games.sorted { $0.lastPlayed > $1.lastPlayed }
    }
    
    // 推荐游戏（用于横幅展示，根据选择的游戏或最近玩的游戏）
    private var featuredGame: GameVersionInfo? {
        selectedGame ?? recentGames.first
    }
    
    var body: some View {
        ZStack {
            // 背景 - 当前游戏图片的高斯模糊
            BlurredGameBackground(game: featuredGame)
            
            VStack(spacing: 0) {
                // 顶部栏 - 右上角玩家信息
                HStack {
                    Spacer()
                    PlayerInfoView()
                        .padding(.trailing, 20)
                        .padding(.top, 12)
                }
                .frame(height: 60)
                
                // 中间内容区域
                ScrollView {
                    VStack(spacing: 0) {
                        // 推荐游戏横幅
                        if let game = featuredGame {
                            FeaturedGameBanner(
                                game: game,
                                onPlay: {
                                    launchGame(game)
                                }
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        }
                        
                        Spacer(minLength: 40)
                        
                        // 底部游戏列表
                        ContinuePlayingSection(
                            games: recentGames,
                            onGameSelected: { game in
                                selectedGame = game
                            },
                            onPlay: { game in
                                launchGame(game)
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Actions
    
    private func launchGame(_ game: GameVersionInfo) {
        Task {
            let isRunning = gameStatusManager.isGameRunning(gameId: game.id)
            if isRunning {
                // 停止游戏
                await MinecraftLaunchCommand(
                    player: playerListViewModel.currentPlayer,
                    game: game,
                    gameRepository: gameRepository
                ).stopGame()
            } else {
                // 启动游戏
                await MinecraftLaunchCommand(
                    player: playerListViewModel.currentPlayer,
                    game: game,
                    gameRepository: gameRepository
                ).launchGame()
            }
        }
    }
}

// MARK: - Blurred Background

/// 模糊的游戏背景视图
private struct BlurredGameBackground: View {
    let game: GameVersionInfo?
    
    var body: some View {
        ZStack {
            // 底层：模糊的游戏图片（如果有）
            if let game = game {
                let profileDir = AppPaths.profileDirectory(gameName: game.gameName)
                let iconURL = profileDir.appendingPathComponent(game.gameIcon)
                
                if FileManager.default.fileExists(atPath: iconURL.path) {
                    AsyncImage(url: iconURL) { phase in
                        switch phase {
                        case .empty:
                            Color.clear
                        case .success(let image):
                            image
                                .resizable()
                                .interpolation(.high)
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .blur(radius: 80)
                                .opacity(0.4)
                                .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                        case .failure:
                            Color.clear
                        @unknown default:
                            Color.clear
                        }
                    }
                    .id(game.id) // 使用游戏ID作为标识，确保切换游戏时重新加载
                }
            }
            
            // 顶层：Material 毛玻璃效果
            Rectangle()
                .fill(.ultraThinMaterial)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: game?.id)
    }
}

// MARK: - Player Info View

/// 右上角玩家信息视图
private struct PlayerInfoView: View {
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @State private var showingPlayerListPopover = false
    
    var body: some View {
        Button {
            showingPlayerListPopover.toggle()
        } label: {
            HStack(spacing: 8) {
                if let player = playerListViewModel.currentPlayer {
                    MinecraftSkinUtils(
                        type: player.isOnlineAccount ? .url : .asset,
                        src: player.avatarName,
                        size: 32
                    )
                    
                    Text(player.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("未选择玩家")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPlayerListPopover, arrowEdge: .top) {
            PlayerListPopoverView()
        }
    }
}

/// 玩家列表弹出视图
private struct PlayerListPopoverView: View {
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var playerToDelete: Player?
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(playerListViewModel.players) { player in
                HStack {
                    Button {
                        playerListViewModel.setCurrentPlayer(byID: player.id)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            MinecraftSkinUtils(
                                type: player.isOnlineAccount ? .url : .asset,
                                src: player.avatarName,
                                size: 36
                            )
                            
                            Text(player.name)
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button {
                        playerToDelete = player
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 250)
        .confirmationDialog(
            "player.remove".localized(),
            isPresented: $showDeleteAlert,
            titleVisibility: .visible
        ) {
            Button("player.remove".localized(), role: .destructive) {
                if let player = playerToDelete {
                    _ = playerListViewModel.deletePlayer(byID: player.id)
                }
                playerToDelete = nil
            }
            .keyboardShortcut(.defaultAction)
            Button("common.cancel".localized(), role: .cancel) {
                playerToDelete = nil
            }
        } message: {
            Text(String(format: "player.remove.confirm".localized(), playerToDelete?.name ?? ""))
        }
    }
}
