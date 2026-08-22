//
//  TouchBarController.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import Observation

/// Owns the main window Touch Bar and keeps its items in sync with app state.
@MainActor
final class TouchBarController: NSObject, NSTouchBarDelegate {
    enum Identifier {
        static let prefix = "com.swiftcraftlauncher.touchbar"
        static let playerPicker = NSTouchBarItem.Identifier("\(prefix).player-picker")
        static let playStop = NSTouchBarItem.Identifier("\(prefix).play-stop")
        static let gamePicker = NSTouchBarItem.Identifier("\(prefix).game-picker")
        static let openSettings = NSTouchBarItem.Identifier("\(prefix).open-settings")

        static let playerPrefix = "\(prefix).player."
        static let gamePrefix = "\(prefix).game."

        static func player(_ id: String) -> NSTouchBarItem.Identifier {
            NSTouchBarItem.Identifier("\(playerPrefix)\(id)")
        }

        static func game(_ id: String) -> NSTouchBarItem.Identifier {
            NSTouchBarItem.Identifier("\(gamePrefix)\(id)")
        }

        static func id(afterPrefix prefix: String, in identifier: String) -> String? {
            guard identifier.hasPrefix(prefix) else { return nil }
            return String(identifier.dropFirst(prefix.count))
        }
    }

    weak var window: NSWindow?
    let touchBar = NSTouchBar()
    var cachedItems: [String: NSTouchBarItem] = [:]
    var playerPickerTouchBar: NSTouchBar?
    var playerPickerItems: [String: NSTouchBarItem] = [:]
    var gamePickerTouchBar: NSTouchBar?
    var gamePickerItems: [String: NSTouchBarItem] = [:]
    var gamePickerIDs: [String] = []
    var gamePickerGames: [GameVersionInfo] = []
    var playerPickerIDs: [String] = []

    var container: DIContainer?
    var gameRepository: GameRepository?
    var gameLaunchUseCase: GameLaunchUseCase?
    var playerListViewModel: PlayerListViewModel?
    var openSettingsAction: (@MainActor () -> Void)?

    private var isObservingState = false
    private var observationGeneration = 0

    func install(on window: NSWindow) {
        guard self.window !== window else { return }
        self.window = window
        touchBar.delegate = self
        window.touchBar = touchBar
    }

    func update(with configuration: TouchBarConfiguration) {
        container = configuration.container
        gameRepository = configuration.gameRepository
        gameLaunchUseCase = configuration.gameLaunchUseCase
        playerListViewModel = configuration.playerListViewModel
        openSettingsAction = configuration.openSettings

        refresh()
        scheduleStateObservationIfNeeded()
    }

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier,
    ) -> NSTouchBarItem? {
        if touchBar === self.touchBar {
            if let item = cachedItems[identifier.rawValue] {
                return item
            }
            return makeMainItem(for: identifier)
        }
        if touchBar === playerPickerTouchBar {
            return makePlayerPickerItem(for: identifier)
        }
        if touchBar === gamePickerTouchBar {
            return makeGamePickerItem(for: identifier)
        }
        return nil
    }

    func refresh() {
        let games = gameRepository?.games ?? []
        let players = playerListViewModel?.players ?? []
        let selectedGame = resolveSelectedGame(in: games)

        let gameIDsSummary = games.map(\.id).joined(separator: ",")
        AppLog.touchbar.debug(
            "Touch Bar refresh: \(games.count) games [\(gameIDsSummary)], \(players.count) players, selected=\(selectedGame?.gameName ?? "none")",
        )

        configureTouchBarLayout(playerCount: players.count, gameCount: games.count)
        if players.count > 1 {
            updatePlayerPicker(currentPlayer: playerListViewModel?.currentPlayer)
        } else {
            playerPickerIDs = []
        }
        if !games.isEmpty {
            updateGamePicker(games: games, selectedGame: selectedGame)
        } else {
            gamePickerIDs = []
        }
        updatePlayStopItem(selectedGame: selectedGame, currentPlayer: playerListViewModel?.currentPlayer)
    }

    private func configureTouchBarLayout(playerCount: Int, gameCount: Int) {
        var identifiers: [NSTouchBarItem.Identifier] = []
        if playerCount > 1 {
            identifiers.append(Identifier.playerPicker)
        }
        identifiers.append(Identifier.playStop)
        if gameCount > 0 {
            identifiers.append(Identifier.gamePicker)
        }
        identifiers.append(Identifier.openSettings)

        touchBar.defaultItemIdentifiers = identifiers
        touchBar.principalItemIdentifier = nil
    }

    private func scheduleStateObservationIfNeeded() {
        guard !isObservingState else { return }
        isObservingState = true
        observationGeneration += 1
        let generation = observationGeneration

        withObservationTracking {
            _ = observedStateFingerprint()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                isObservingState = false
                guard generation == observationGeneration else { return }
                refresh()
                scheduleStateObservationIfNeeded()
            }
        }
    }

    private func observedStateFingerprint() -> Int {
        var fingerprint = gameRepository?.games.count ?? 0
        fingerprint &+= playerListViewModel?.players.count ?? 0
        fingerprint &+= playerListViewModel?.currentPlayer?.id.hashValue ?? 0
        fingerprint &+= container?.core.selectedGameManager.selectedGameId?.hashValue ?? 0

        let userId = playerListViewModel?.currentPlayer?.id ?? ""
        for game in gameRepository?.games ?? [] {
            let isRunning = container?.core.gameStatusManager.cachedIsGameRunning(gameId: game.id, userId: userId) ?? false
            let isLaunching = container?.core.gameStatusManager.isGameLaunching(gameId: game.id, userId: userId) ?? false
            fingerprint &+= isRunning ? 1 : 0
            fingerprint &+= isLaunching ? 1 : 0
        }
        return fingerprint
    }
}
