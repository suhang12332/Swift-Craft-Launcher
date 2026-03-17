import Foundation
import SwiftUI

@MainActor
final class AIChatWindowViewModel: ObservableObject {
    @Published var selectedGameId: String?
    @Published var cachedAIAvatar: AnyView?
    @Published var cachedUserAvatar: AnyView?

    private enum Constants {
        static let avatarSize: CGFloat = 32
    }

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

    func onGamesChanged(_ games: [GameVersionInfo]) {
        if selectedGameId == nil, let first = games.first?.id {
            selectedGameId = first
        }
    }

    func onPlayerChanged(_ player: Player?) {
        updateUserAvatarCache(currentPlayer: player)
    }

    func onAIAvatarURLChanged(_ newURL: String) {
        updateAIAvatarCache(aiAvatarURL: newURL)
    }

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
