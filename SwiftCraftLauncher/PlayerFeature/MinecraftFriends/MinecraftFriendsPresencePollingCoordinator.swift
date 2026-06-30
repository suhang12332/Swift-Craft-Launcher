//
//  MinecraftFriendsPresencePollingCoordinator.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Combine
import Foundation
import MinecraftFriendsKit

/// Coordinates periodic polling of Minecraft friends presence and friend list updates.
///
/// This singleton observes the current player and the presence notifications setting
/// to start or stop a background polling loop. The loop runs at a fixed 10-second
/// interval while a Microsoft account is selected and presence notifications are enabled.
@MainActor
final class MinecraftFriendsPresencePollingCoordinator {
    static let shared = MinecraftFriendsPresencePollingCoordinator()

    private static let pollingIntervalNanoseconds: UInt64 = 10_000_000_000

    private let hostAdapter: MinecraftFriendsPresenceMonitorHostAdapter
    private let presenceMonitor: MinecraftFriendsPresenceMonitor
    private let friendListMonitor: MinecraftFriendsFriendListMonitor
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
            dataManager: AppServices.playerDataManager,
            errorHandler: AppServices.errorHandler
        )
        let localize = Self.makeLocalize()
        presenceMonitor = MinecraftFriendsPresenceMonitor(
            friendsService: friendsService,
            host: hostAdapter,
            preferencesDidChangeNotification: .minecraftFriendsAccountPreferencesDidChange,
            localize: localize
        )
        friendListMonitor = MinecraftFriendsFriendListMonitor(
            friendsService: friendsService,
            host: hostAdapter,
            preferencesDidChangeNotification: .minecraftFriendsAccountPreferencesDidChange,
            localize: localize
        )
    }

    /// Starts observing the player list view model and begins polling if conditions are met.
    ///
    /// - Parameter playerListViewModel: The view model whose current player is observed.
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

    /// Stops all observations and the polling loop.
    func stop() {
        currentPlayerObservation?.cancel()
        currentPlayerObservation = nil
        presenceNotificationsSettingObservation?.cancel()
        presenceNotificationsSettingObservation = nil
        playerListViewModel = nil
        stopPollingLoop()
    }

    /// Starts or stops the polling loop based on the current player and settings.
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

                let presenceContext = MinecraftFriendsPresenceTickContext(
                    playerId: boundPlayer.id,
                    canUseMicrosoftMinecraftServices: true
                )
                await presenceMonitor.tick(context: presenceContext)

                let friendListContext = MinecraftFriendsFriendListTickContext(
                    playerId: boundPlayer.id,
                    canUseMicrosoftMinecraftServices: true
                )
                await friendListMonitor.tick(context: friendListContext)
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
        player.isOnlineAccount && !OfflineUserServerMap.contains(userId: player.id)
    }

    private static func makeLocalize() -> (String) -> String {
        MinecraftFriendsSheetLocalize.resolver(
            localeIdentifier: { AppServices.languageManager.selectedLanguage },
            fallback: { $0.localized() }
        )
    }
}
