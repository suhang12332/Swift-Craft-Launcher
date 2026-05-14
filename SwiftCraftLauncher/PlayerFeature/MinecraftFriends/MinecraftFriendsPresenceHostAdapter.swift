import Foundation
import MinecraftFriendsKit

@MainActor
final class MinecraftFriendsPresenceHostAdapter: MinecraftFriendsPresenceMonitorHost {
    static let shared = MinecraftFriendsPresenceHostAdapter()

    weak var playerListViewModel: PlayerListViewModel?

    private let authService: MinecraftAuthService
    private let sideEffects: MinecraftFriendsMicrosoftPlayerSideEffects

    private init(
        authService: MinecraftAuthService = AppServices.minecraftAuthService,
        dataManager: PlayerDataManager = PlayerDataManager(),
        errorHandler: GlobalErrorHandler = AppServices.errorHandler
    ) {
        self.authService = authService
        self.sideEffects = MinecraftFriendsMicrosoftPlayerSideEffects(
            dataManager: dataManager,
            errorHandler: errorHandler
        )
    }

    func attach(playerListViewModel: PlayerListViewModel) {
        self.playerListViewModel = playerListViewModel
    }

    func friendsAccessToken(playerId: String) async -> String? {
        await MinecraftFriendsHostMicrosoftAccessToken.resolve(
            requestedPlayerId: playerId,
            boundPlayerId: { self.playerListViewModel?.currentPlayer?.id ?? "" },
            copyBoundPlayer: { self.playerListViewModel?.currentPlayer },
            mergeCredentialFromDiskIfNeeded: { p in
                self.sideEffects.loadCredentialFromDiskIfMissing(into: &p)
            },
            minecraftAccessToken: { $0.authAccessToken },
            refreshPlayerToken: { try await self.authService.validateAndRefreshPlayerTokenThrowing(for: $0) },
            persistIfMinecraftAccessTokenChanged: { _, after in
                self.sideEffects.persistPlayerIfNeeded(after)
            },
            applyRefreshedPlayer: { _ in },
            onMissingMinecraftAccessToken: { self.sideEffects.reportMissingAccessToken() },
            onRefreshFailure: { _ in }
        )
    }

    func sendSilentNotification(title: String, body: String) async {
        await NotificationManager.sendSilently(title: title, body: body)
    }
}
