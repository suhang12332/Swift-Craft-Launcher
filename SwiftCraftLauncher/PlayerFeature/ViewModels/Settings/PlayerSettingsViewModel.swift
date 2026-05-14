import Combine
import Foundation
import MinecraftFriendsKit

@MainActor
final class PlayerSettingsViewModel: ObservableObject {
    @Published var isDownloadingAuthlibInjector: Bool = false
    @Published var authlibInjectorExists: Bool = false

    @Published private(set) var minecraftFriendAccountPreferences: MinecraftFriendsPreferencesPayload?
    @Published private(set) var isLoadingMinecraftFriendAccountPreferences = false
    @Published private(set) var isSavingMinecraftFriendAccountPreferences = false

    private let friendsService: MinecraftFriendsService
    private let authService: MinecraftAuthService
    private let sideEffects: MinecraftFriendsMicrosoftPlayerSideEffects

    init(
        friendsService: MinecraftFriendsService = AppServices.minecraftFriendsService,
        authService: MinecraftAuthService = .shared,
        dataManager: PlayerDataManager = PlayerDataManager(),
        errorHandler: GlobalErrorHandler = AppServices.errorHandler
    ) {
        self.friendsService = friendsService
        self.authService = authService
        self.sideEffects = MinecraftFriendsMicrosoftPlayerSideEffects(
            dataManager: dataManager,
            errorHandler: errorHandler
        )
    }

    func refreshAuthlibInjectorExists() {
        let authlibInjectorJarURL = AppPaths.authDirectory.appendingPathComponent(
            AppConstants.AuthlibInjector.jarFileName
        )
        authlibInjectorExists = FileManager.default.fileExists(atPath: authlibInjectorJarURL.path)
    }

    func downloadAuthlibInjector() async {
        guard !isDownloadingAuthlibInjector else { return }
        isDownloadingAuthlibInjector = true
        defer { isDownloadingAuthlibInjector = false }

        let authlibInjectorJarURL = AppPaths.authDirectory.appendingPathComponent(
            AppConstants.AuthlibInjector.jarFileName
        )

        do {
            let downloadURL = URLConfig.API.AuthlibInjector.download
            _ = try await DownloadManager.downloadFile(
                urlString: downloadURL.absoluteString,
                destinationURL: authlibInjectorJarURL,
                expectedSha1: nil
            )
            authlibInjectorExists = true
        } catch {
            let globalError = GlobalError.download(
                chineseMessage: "下载 authlib-injector 失败: \(error.localizedDescription)",
                i18nKey: "error.download.authlib_injector_failed",
                level: .notification
            )
            sideEffects.handle(globalError)
        }
    }

    func clearMinecraftFriendAccountPreferences() {
        minecraftFriendAccountPreferences = nil
        isLoadingMinecraftFriendAccountPreferences = false
        isSavingMinecraftFriendAccountPreferences = false
    }

    func reloadMinecraftFriendAccountPreferences(currentPlayer: Player?) async {
        guard let player = currentPlayer, player.canUseMicrosoftMinecraftServices else {
            clearMinecraftFriendAccountPreferences()
            return
        }

        isLoadingMinecraftFriendAccountPreferences = true
        defer { isLoadingMinecraftFriendAccountPreferences = false }

        guard let tokenPlayer = await preparedTokenPlayer(for: player, onMissingCredential: sideEffects.reportMissingAccessToken) else {
            minecraftFriendAccountPreferences = nil
            return
        }

        do {
            minecraftFriendAccountPreferences = try await friendsService.fetchFriendAccountPreferences(
                accessToken: tokenPlayer.authAccessToken
            )
            NotificationCenter.default.post(name: .minecraftFriendsAccountPreferencesDidChange, object: nil)
        } catch {
            minecraftFriendAccountPreferences = nil
            sideEffects.reportGlobalError(error)
        }
    }

    func setMinecraftFriendListEnabled(_ enabled: Bool, currentPlayer: Player?) async {
        let invitesOn = minecraftFriendAccountPreferences?.acceptInvites == .enabled
        await persistMinecraftFriendAccountPreferences(
            currentPlayer: currentPlayer,
            enableFriendlist: enabled,
            enableFriendInvites: invitesOn
        )
    }

    func setMinecraftFriendAcceptInvitesEnabled(_ enabled: Bool, currentPlayer: Player?) async {
        let friendsOn = minecraftFriendAccountPreferences?.friends == .enabled
        await persistMinecraftFriendAccountPreferences(
            currentPlayer: currentPlayer,
            enableFriendlist: friendsOn,
            enableFriendInvites: enabled
        )
    }

    private func persistMinecraftFriendAccountPreferences(
        currentPlayer: Player?,
        enableFriendlist: Bool,
        enableFriendInvites: Bool
    ) async {
        guard let player = currentPlayer, player.canUseMicrosoftMinecraftServices else { return }
        guard let tokenPlayer = await preparedTokenPlayer(for: player, onMissingCredential: sideEffects.reportMissingAccessToken) else { return }

        isSavingMinecraftFriendAccountPreferences = true
        defer { isSavingMinecraftFriendAccountPreferences = false }

        do {
            try await friendsService.updateFriendSettings(
                accessToken: tokenPlayer.authAccessToken,
                enableFriendlist: enableFriendlist,
                enableFriendInvites: enableFriendInvites
            )
            minecraftFriendAccountPreferences = try await friendsService.fetchFriendAccountPreferences(
                accessToken: tokenPlayer.authAccessToken
            )
            NotificationCenter.default.post(name: .minecraftFriendsAccountPreferencesDidChange, object: nil)
        } catch {
            sideEffects.reportGlobalError(error)
            await reloadMinecraftFriendAccountPreferences(currentPlayer: currentPlayer)
        }
    }

    private func preparedTokenPlayer(for player: Player, onMissingCredential: () -> Void) async -> Player? {
        var resolved = player
        sideEffects.loadCredentialFromDiskIfMissing(into: &resolved)
        guard !resolved.authAccessToken.isEmpty else {
            onMissingCredential()
            return nil
        }

        do {
            let tokenPlayer = try await authService.validateAndRefreshPlayerTokenThrowing(for: resolved)
            if tokenPlayer.authAccessToken != resolved.authAccessToken {
                sideEffects.persistPlayerIfNeeded(tokenPlayer)
            }
            return tokenPlayer
        } catch {
            sideEffects.reportGlobalError(error)
            return nil
        }
    }
}
