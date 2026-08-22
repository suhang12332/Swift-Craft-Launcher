//
//  TouchBarController.swift
//  TouchBarSupport
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
        static let playerLabel = NSTouchBarItem.Identifier("\(prefix).player-label")
        static let playStop = NSTouchBarItem.Identifier("\(prefix).play-stop")
        static let gamePicker = NSTouchBarItem.Identifier("\(prefix).game-picker")
        static let openSettings = NSTouchBarItem.Identifier("\(prefix).open-settings")

        static let gamePrefix = "\(prefix).game."

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
    var gamePickerTouchBar: NSTouchBar?
    var gamePickerItems: [String: NSTouchBarItem] = [:]
    var gamePickerIDs: [String] = []
    var gamePickerInstances: [TouchBarInstance] = []
    var configuration: TouchBarSupportConfiguration?

    private var isObservingState = false
    private var observationGeneration = 0

    func install(on window: NSWindow) {
        guard self.window !== window else { return }
        self.window = window
        touchBar.delegate = self
        window.touchBar = touchBar
    }

    func update(with configuration: TouchBarSupportConfiguration) {
        self.configuration = configuration
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
        if touchBar === gamePickerTouchBar {
            return makeGamePickerItem(for: identifier)
        }
        return nil
    }

    func refresh() {
        let instances = configuration?.instances() ?? []
        let currentPlayer = configuration?.currentPlayerName()
        let selectedGame = resolveSelectedGame(in: instances)

        let idsSummary = instances.map(\.id).joined(separator: ",")
        TouchBarLog.log.debug("Touch Bar refresh: \(instances.count) instances [\(idsSummary)], player=\(currentPlayer ?? "none"), selected=\(selectedGame?.name ?? "none")")

        configureTouchBarLayout(hasPlayer: currentPlayer != nil, hasInstance: !instances.isEmpty)
        updatePlayerLabelItem(currentPlayer: currentPlayer)
        if !instances.isEmpty {
            updateGamePicker(instances: instances, selectedGame: selectedGame)
        } else {
            gamePickerIDs = []
        }
        updatePlayStopItem(selectedGame: selectedGame, hasCurrentPlayer: currentPlayer != nil)
    }

    private func configureTouchBarLayout(hasPlayer: Bool, hasInstance: Bool) {
        var identifiers: [NSTouchBarItem.Identifier] = []
        if hasPlayer {
            identifiers.append(Identifier.playerLabel)
        }
        identifiers.append(Identifier.playStop)
        if hasInstance {
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
        var fingerprint = configuration?.instances().count ?? 0
        fingerprint &+= configuration?.currentPlayerName()?.hashValue ?? 0
        fingerprint &+= configuration?.currentInstanceID()?.hashValue ?? 0

        for instance in configuration?.instances() ?? [] {
            fingerprint &+= (configuration?.isRunning(instance.id) ?? false) ? 1 : 0
            fingerprint &+= (configuration?.isLaunching(instance.id) ?? false) ? 1 : 0
        }
        return fingerprint
    }
}
