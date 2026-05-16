import Foundation

/// Disk credential merge, missing-token reporting, and silent player persistence shared by Microsoft Minecraft friends flows.
@MainActor
struct MinecraftFriendsMicrosoftPlayerSideEffects {
    let dataManager: PlayerDataManager
    let errorHandler: GlobalErrorHandler

    func loadCredentialFromDiskIfMissing(into player: inout Player) {
        if player.credential == nil {
            player.credential = dataManager.loadCredential(userId: player.id)
        }
    }

    func reportMissingAccessToken() {
        errorHandler.handle(
            GlobalError.authentication(
                chineseMessage: "缺少 Minecraft 访问令牌，请重新登录该正版账号",
                i18nKey: "error.authentication.missing_token",
                level: .notification
            )
        )
    }

    func persistPlayerIfNeeded(_ updated: Player) {
        guard dataManager.updatePlayerSilently(updated) else { return }
        NotificationCenter.default.post(
            name: .playerUpdated,
            object: nil,
            userInfo: ["updatedPlayer": updated]
        )
    }

    func reportGlobalError(_ error: Error) {
        errorHandler.handle(GlobalError.from(error))
    }

    func handle(_ error: GlobalError) {
        errorHandler.handle(error)
    }
}
