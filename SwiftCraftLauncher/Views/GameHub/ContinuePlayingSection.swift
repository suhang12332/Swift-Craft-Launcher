//
//  ContinuePlayingSection.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/28.
//

import SwiftUI

/// 继续游戏部分 - 底部横向滚动的游戏列表
struct ContinuePlayingSection: View {
    let games: [GameVersionInfo]
    let onGameSelected: (GameVersionInfo) -> Void
    let onPlay: (GameVersionInfo) -> Void
    
    @StateObject private var gameStatusManager = GameStatusManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            Text("继续游戏")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
            
            // 横向滚动的游戏列表
            if games.isEmpty {
                emptyStateView
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(games) { game in
                            GameLibraryCard(
                                game: game,
                                isRunning: gameStatusManager.isGameRunning(gameId: game.id),
                                onTap: {
                                    onGameSelected(game)
                                },
                                onPlay: {
                                    onPlay(game)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("还没有游戏")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("点击右上角的 + 按钮添加游戏")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

/// 游戏库卡片组件
struct GameLibraryCard: View {
    let game: GameVersionInfo
    let isRunning: Bool
    let onTap: () -> Void
    let onPlay: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        // 游戏图标 - 可点击
        ZStack {
            gameIcon
            
            // 运行状态指示器
            if isRunning {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .shadow(color: Color.green.opacity(0.5), radius: 4)
                            .padding(8)
                    }
                    Spacer()
                }
            }
            
            // 悬停时显示的覆盖层
            if isHovered {
                ZStack {
                    // ultraThinMaterial 背景
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                    
                    // 播放按钮
                    Button(action: onPlay) {
                        Image(systemName: isRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(isRunning ? Color.orange : Color.accentColor)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
            // 鼠标悬停时切换游戏
            if hovering {
                onTap()
            }
        }
    }
    
    // MARK: - Game Icon
    
    private var gameIcon: some View {
        let profileDir = AppPaths.profileDirectory(gameName: game.gameName)
        let iconURL = profileDir.appendingPathComponent(game.gameIcon)
        
        return Group {
            if FileManager.default.fileExists(atPath: iconURL.path) {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .empty:
                        defaultIcon
                    case .success(let image):
                        image
                            .resizable()
                            .interpolation(.high)
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                    case .failure:
                        defaultIcon
                    @unknown default:
                        defaultIcon
                    }
                }
            } else {
                defaultIcon
            }
        }
    }
    
    private var defaultIcon: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.3, green: 0.2, blue: 0.4),
                    Color(red: 0.4, green: 0.3, blue: 0.5)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 30))
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(width: 80, height: 80)
    }
    
    // MARK: - Game Version Text
    
    private var gameVersionText: String {
        var text = game.gameVersion
        if !game.modLoader.isEmpty && game.modLoader.lowercased() != "vanilla" {
            text += " • \(game.modLoader)"
        }
        return text
    }
}
