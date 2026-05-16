import Foundation
import MinecraftFriendsKit

@MainActor
final class MinecraftFriendsPresenceMonitorHostAdapter: MinecraftFriendsPresenceMonitorHost {
    private var player: Player?
    private let authService: MinecraftAuthService
    private let sideEffects: MinecraftFriendsMicrosoftPlayerSideEffects

    init(
        player: Player? = nil,
        authService: MinecraftAuthService = AppServices.minecraftAuthService,
        dataManager: PlayerDataManager = PlayerDataManager(),
        errorHandler: GlobalErrorHandler = AppServices.errorHandler
    ) {
        self.player = player
        self.authService = authService
        self.sideEffects = MinecraftFriendsMicrosoftPlayerSideEffects(
            dataManager: dataManager,
            errorHandler: errorHandler
        )
    }

    func setBoundPlayer(_ player: Player?) {
        self.player = player
    }

    func friendsAccessToken(playerId: String) async -> String? {
        await MinecraftFriendsHostMicrosoftAccessToken.resolve(
            requestedPlayerId: playerId,
            boundPlayerId: { self.player?.id ?? "" },
            copyBoundPlayer: { self.player },
            mergeCredentialFromDiskIfNeeded: { p in
                self.sideEffects.loadCredentialFromDiskIfMissing(into: &p)
            },
            minecraftAccessToken: { $0.authAccessToken },
            refreshPlayerToken: { try await self.authService.validateAndRefreshPlayerTokenThrowing(for: $0) },
            persistIfMinecraftAccessTokenChanged: { _, after in
                self.sideEffects.persistPlayerIfNeeded(after)
            },
            applyRefreshedPlayer: { self.player = $0 },
            onMissingMinecraftAccessToken: { self.sideEffects.reportMissingAccessToken() },
            onRefreshFailure: { self.sideEffects.reportGlobalError($0) }
        )
    }

    func sendSilentNotification(title: String, body: String) async {
        await NotificationManager.sendSilently(title: title, body: body)
    }
}
