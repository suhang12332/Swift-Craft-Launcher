//
//  FeaturedGameBanner.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/28.
//

import SwiftUI

/// 推荐游戏横幅组件
struct FeaturedGameBanner: View {
    let game: GameVersionInfo
    let onPlay: () -> Void
    
    @StateObject private var gameStatusManager = GameStatusManager.shared
    
    private var isGameRunning: Bool {
        gameStatusManager.isGameRunning(gameId: game.id)
    }
    
    var body: some View {
        // 内容区域（无背景）
        VStack(alignment: .leading, spacing: 12) {
            Text("为你推荐")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary.opacity(0.7))
            
            Text(game.gameName)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Text(gameDescription)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .lineLimit(1)

            // 播放按钮
            Button(action: onPlay) {
                HStack(spacing: 6) {
                    Image(systemName: isGameRunning ? "stop.fill" : "play.fill")
                    Text(isGameRunning ? "停止游戏" : "开始游戏")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.9))
                )
            }
            .buttonStyle(.plain)
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(40)
        .frame(maxWidth: 400, alignment: .leading)
    }
    
    // MARK: - Game Description
    
    private var gameDescription: String {
        var desc = "Minecraft \(game.gameVersion)"
        if !game.modLoader.isEmpty && game.modLoader.lowercased() != "vanilla" {
            desc += " • \(game.modLoader)"
        }
        if !game.modVersion.isEmpty {
            desc += " \(game.modVersion)"
        }
        return desc
    }
}
