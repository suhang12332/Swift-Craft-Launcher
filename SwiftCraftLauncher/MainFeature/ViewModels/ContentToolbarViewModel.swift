import Foundation
import SwiftUI

@MainActor
final class ContentToolbarViewModel: ObservableObject {
    @Published var isLoadingSkin: Bool = false
    @Published var preloadedSkinInfo: PlayerSkinService.PublicSkinInfo?
    @Published var preloadedProfile: MinecraftProfileResponse?
    private let authService: MinecraftAuthService

    init(authService: MinecraftAuthService = AppServices.minecraftAuthService) {
        self.authService = authService
    }

    func preloadSkinDataForManager(player: Player?) async {
        guard let player else { return }

        isLoadingSkin = true
        defer { isLoadingSkin = false }

        if !player.isOnlineAccount {
            async let skinInfo = PlayerSkinService.fetchCurrentPlayerSkinFromServices(player: player)
            async let profile = PlayerSkinService.fetchPlayerProfile(player: player)
            let (loadedSkinInfo, loadedProfile) = await (skinInfo, profile)
            preloadedSkinInfo = loadedSkinInfo
            preloadedProfile = loadedProfile
            return
        }

        Logger.shared.info("打开皮肤管理器前验证玩家 \(player.name) 的Token")

        var playerWithCredential = player
        if playerWithCredential.credential == nil {
            let dataManager = PlayerDataManager()
            if let credential = dataManager.loadCredential(userId: playerWithCredential.id) {
                playerWithCredential.credential = credential
            }
        }

        let validatedPlayer: Player
        do {
            validatedPlayer = try await authService.validateAndRefreshPlayerTokenThrowing(for: playerWithCredential)

            if validatedPlayer.authAccessToken != player.authAccessToken {
                Logger.shared.info("玩家 \(player.name) 的Token已更新，保存到数据管理器")
                let dataManager = PlayerDataManager()
                let success = dataManager.updatePlayerSilently(validatedPlayer)
                if success {
                    Logger.shared.debug("已更新玩家数据管理器中的Token信息")
                    NotificationCenter.default.post(
                        name: .playerUpdated,
                        object: nil,
                        userInfo: ["updatedPlayer": validatedPlayer]
                    )
                }
            }
        } catch {
            Logger.shared.error("刷新Token失败: \(error.localizedDescription)")
            validatedPlayer = playerWithCredential
        }

        async let skinInfo = PlayerSkinService.fetchCurrentPlayerSkinFromServices(player: validatedPlayer)
        async let profile = PlayerSkinService.fetchPlayerProfile(player: validatedPlayer)
        let (loadedSkinInfo, loadedProfile) = await (skinInfo, profile)
        preloadedSkinInfo = loadedSkinInfo
        preloadedProfile = loadedProfile
    }

    func clearPreloadedSkinData() {
        preloadedSkinInfo = nil
        preloadedProfile = nil
    }
}
