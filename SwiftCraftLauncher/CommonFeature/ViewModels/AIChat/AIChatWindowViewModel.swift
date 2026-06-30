//
//  AIChatWindowViewModel.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Manages state and cached avatars for the AI chat window.
@MainActor
final class AIChatWindowViewModel: ObservableObject {
    @Published var selectedGameId: String?
    @Published var cachedAIAvatar: AnyView?
    @Published var cachedUserAvatar: AnyView?

    private enum Constants {
        static let avatarSize: CGFloat = 32
    }

    /// Initializes the view with games, player, and AI avatar URL.
    func onAppear(
        games: [GameVersionInfo],
        currentPlayer: Player?,
        aiAvatarURL: String
    ) {
        if selectedGameId == nil, let first = games.first?.id {
            selectedGameId = first
        }
        updateAIAvatarCache(aiAvatarURL: aiAvatarURL)
        updateUserAvatarCache(currentPlayer: currentPlayer)
    }

    /// Updates the selected game when available games change.
    func onGamesChanged(_ games: [GameVersionInfo]) {
        if selectedGameId == nil, let first = games.first?.id {
            selectedGameId = first
        }
    }

    /// Refreshes the user avatar when the current player changes.
    func onPlayerChanged(_ player: Player?) {
        updateUserAvatarCache(currentPlayer: player)
    }

    /// Refreshes the AI avatar when the URL changes.
    func onAIAvatarURLChanged(_ newURL: String) {
        updateAIAvatarCache(aiAvatarURL: newURL)
    }

    /// Clears all cached data and resets the selected game.
    func clearAllData() {
        cachedAIAvatar = nil
        cachedUserAvatar = nil
        selectedGameId = nil
    }

    private func updateAIAvatarCache(aiAvatarURL: String) {
        cachedAIAvatar = AnyView(
            AIAvatarView(size: Constants.avatarSize, url: aiAvatarURL)
        )
    }

    private func updateUserAvatarCache(currentPlayer: Player?) {
        if let player = currentPlayer {
            cachedUserAvatar = AnyView(
                MinecraftSkinUtils(
                    type: player.isRemote ? .url : .asset,
                    src: player.avatarName,
                    size: Constants.avatarSize
                )
            )
        } else {
            cachedUserAvatar = AnyView(
                Image(systemName: "person.fill")
                    .font(.system(size: Constants.avatarSize))
                    .foregroundStyle(.secondary)
            )
        }
    }
}
