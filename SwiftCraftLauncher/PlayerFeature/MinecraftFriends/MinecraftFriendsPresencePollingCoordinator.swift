import Combine
import Foundation
import MinecraftFriendsKit

@MainActor
final class MinecraftFriendsPresencePollingCoordinator {
    static let shared = MinecraftFriendsPresencePollingCoordinator()

    private static let pollingIntervalNanoseconds: UInt64 = 10_000_000_000

    private let hostAdapter: MinecraftFriendsPresenceMonitorHostAdapter
    private let monitor: MinecraftFriendsPresenceMonitor
    private let credentialSideEffects: MinecraftFriendsMicrosoftPlayerSideEffects

    private weak var playerListViewModel: PlayerListViewModel?
    private var currentPlayerObservation: AnyCancellable?
    private var presenceNotificationsSettingObservation: AnyCancellable?
    private var pollingTask: Task<Void, Never>?
    private var pollingGeneration = 0
    private var lastPresenceNotificationsEnabled =
        AppServices.playerSettingsManager.enableMinecraftFriendsPresenceNotifications

    private init(
        friendsService: MinecraftFriendsService = AppServices.minecraftFriendsService
    ) {
        hostAdapter = MinecraftFriendsPresenceMonitorHostAdapter()
        credentialSideEffects = MinecraftFriendsMicrosoftPlayerSideEffects(
            dataManager: PlayerDataManager(),
            errorHandler: AppServices.errorHandler
        )
        monitor = MinecraftFriendsPresenceMonitor(
            friendsService: friendsService,
            host: hostAdapter,
            preferencesDidChangeNotification: .minecraftFriendsAccountPreferencesDidChange,
            localize: Self.makeLocalize()
        )
    }

    func start(playerListViewModel: PlayerListViewModel) {
        self.playerListViewModel = playerListViewModel

        guard currentPlayerObservation == nil else {
            syncPollingToCurrentPlayer()
            return
        }

        currentPlayerObservation = playerListViewModel.$currentPlayer
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncPollingToCurrentPlayer()
            }

        let playerSettings = AppServices.playerSettingsManager
        presenceNotificationsSettingObservation = playerSettings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                let enabled = playerSettings.enableMinecraftFriendsPresenceNotifications
                guard enabled != lastPresenceNotificationsEnabled else { return }
                lastPresenceNotificationsEnabled = enabled
                syncPollingToCurrentPlayer()
            }

        syncPollingToCurrentPlayer()
    }

    func stop() {
        currentPlayerObservation?.cancel()
        currentPlayerObservation = nil
        presenceNotificationsSettingObservation?.cancel()
        presenceNotificationsSettingObservation = nil
        playerListViewModel = nil
        stopPollingLoop()
    }

    private func syncPollingToCurrentPlayer() {
        guard AppServices.playerSettingsManager.enableMinecraftFriendsPresenceNotifications else {
            stopPollingLoop()
            return
        }

        let player = playerListViewModel?.currentPlayer
        if player.map(Self.canUseMicrosoftMinecraftServices(for:)) == true {
            startPollingLoopIfNeeded()
        } else {
            stopPollingLoop()
        }
    }

    private func startPollingLoopIfNeeded() {
        guard pollingTask == nil, let playerListViewModel else { return }
        let generation = pollingGeneration
        pollingTask = Task { [weak playerListViewModel] in
            guard let playerListViewModel else { return }
            await runLoop(playerListViewModel: playerListViewModel, generation: generation)
        }
    }

    private func stopPollingLoop() {
        pollingGeneration += 1
        pollingTask?.cancel()
        pollingTask = nil
        hostAdapter.setBoundPlayer(nil)
    }

    private func runLoop(playerListViewModel: PlayerListViewModel, generation: Int) async {
        defer {
            if generation == pollingGeneration {
                pollingTask = nil
            }
        }

        while !Task.isCancelled {
            let tickCompleted = await RoutineAuthDiagnosticsLogContext.withSuppressedRoutineDebugLogs {
                let boundPlayer = preparedBoundPlayer(from: playerListViewModel.currentPlayer)
                guard let boundPlayer, Self.canUseMicrosoftMinecraftServices(for: boundPlayer) else {
                    return false
                }

                hostAdapter.setBoundPlayer(boundPlayer)

                let context = MinecraftFriendsPresenceTickContext(
                    playerId: boundPlayer.id,
                    canUseMicrosoftMinecraftServices: true
                )
                await monitor.tick(context: context)
                return true
            }

            guard tickCompleted else { break }

            do {
                try await Task.sleep(nanoseconds: Self.pollingIntervalNanoseconds)
            } catch {
                break
            }
        }
    }

    private func preparedBoundPlayer(from player: Player?) -> Player? {
        guard var player else { return nil }
        credentialSideEffects.loadCredentialFromDiskIfMissing(into: &player)
        return player
    }

    private static func canUseMicrosoftMinecraftServices(for player: Player) -> Bool {
        player.isOnlineAccount && OfflineUserServerMap.serverKey(for: player.id) == nil
    }

    private static func makeLocalize() -> (String) -> String {
        MinecraftFriendsSheetLocalize.resolver(
            localeIdentifier: { LanguageManager.getDefaultLanguage() },
            fallback: { $0.localized() }
        )
    }
}
