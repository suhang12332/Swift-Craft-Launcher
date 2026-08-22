//
//  TouchBarController+Actions.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit

extension TouchBarController {
    func symbolImage(_ name: String, accessibilityDescription: String? = nil) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription) ?? NSImage()
    }

    /// Keeps the read-only current-player label in sync with the active player.
    func updatePlayerLabelItem(currentPlayer: Player?) {
        guard let item = cachedItems[Identifier.playerLabel.rawValue] as? NSCustomTouchBarItem,
              let label = item.view as? NSTextField else { return }
        label.stringValue = currentPlayer?.name ?? ""
    }

    func updatePlayStopItem(selectedGame: GameVersionInfo?, currentPlayer: Player?) {
        let item = mainItem(Identifier.playStop) {
            NSButtonTouchBarItem(
                identifier: Identifier.playStop,
                title: "play.fill".localized(),
                target: self,
                action: #selector(toggleSelectedGame),
            )
        }
        guard let button = item as? NSButtonTouchBarItem else { return }

        let userId = currentPlayer?.id ?? ""
        let isRunning = selectedGame.map {
            container?.core.gameStatusManager.isGameRunning(gameId: $0.id, userId: userId) ?? false
        } ?? false
        let isLaunching = selectedGame.map {
            container?.core.gameStatusManager.isGameLaunching(gameId: $0.id, userId: userId) ?? false
        } ?? false
        let title = isRunning ? "common.stop".localized() : "play.fill".localized()

        button.title = title
        button.image = symbolImage(isRunning ? "stop.fill" : "play.fill", accessibilityDescription: title)
        button.isEnabled = selectedGame != nil && currentPlayer != nil && !isLaunching
    }

    func makeMainItem(for identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case Identifier.playerLabel:
            let label = NSTextField(labelWithString: playerListViewModel?.currentPlayer?.name ?? "")
            label.font = NSFont.systemFont(ofSize: 15, weight: .medium)
            label.textColor = .secondaryLabelColor
            label.alignment = .center
            label.lineBreakMode = .byTruncatingTail
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = label
            cachedItems[identifier.rawValue] = item
            return item
        case Identifier.playStop:
            let button = NSButtonTouchBarItem(
                identifier: identifier,
                title: "play.fill".localized(),
                target: self,
                action: #selector(toggleSelectedGame),
            )
            cachedItems[identifier.rawValue] = button
            return button
        case Identifier.gamePicker:
            let picker = NSPopoverTouchBarItem(identifier: identifier)
            picker.showsCloseButton = true
            picker.collapsedRepresentationLabel = "global_resource.select_game".localized()
            cachedItems[identifier.rawValue] = picker
            return picker
        case Identifier.openSettings:
            let button = NSButtonTouchBarItem(
                identifier: identifier,
                title: "touchbar.instance_settings".localized(),
                image: symbolImage("gearshape"),
                target: self,
                action: #selector(openInstanceSettingsFromTouchBar),
            )
            cachedItems[identifier.rawValue] = button
            return button
        default:
            return nil
        }
    }

    func mainItem(_ identifier: NSTouchBarItem.Identifier, factory: () -> NSTouchBarItem) -> NSTouchBarItem {
        if let item = cachedItems[identifier.rawValue] {
            return item
        }
        let item = factory()
        cachedItems[identifier.rawValue] = item
        return item
    }

    func resolveSelectedGame(in games: [GameVersionInfo]) -> GameVersionInfo? {
        guard let selectedId = container?.core.selectedGameManager.selectedGameId else {
            return nil
        }
        return games.first { $0.id == selectedId }
    }

    @objc func toggleSelectedGame() {
        guard let container, let gameLaunchUseCase, let game = resolveSelectedGame(in: gameRepository?.games ?? []) else {
            return
        }
        guard let player = playerListViewModel?.currentPlayer else { return }

        if container.core.selectedGameManager.selectedGameId != game.id {
            container.core.selectedGameManager.setSelectedGame(game.id)
        }

        let userId = player.id
        if container.core.gameStatusManager.isGameRunning(gameId: game.id, userId: userId) {
            Task { @MainActor in
                await gameLaunchUseCase.stopGame(player: player, game: game)
            }
        } else {
            container.core.gameStatusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: true)
            refresh()

            Task { @MainActor in
                defer {
                    container.core.gameStatusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: false)
                }
                await gameLaunchUseCase.launchGame(player: player, game: game)
            }
        }
    }

    @objc func selectGame(_ sender: NSButton) {
        guard let rawIdentifier = sender.identifier?.rawValue,
              let gameId = Identifier.id(afterPrefix: Identifier.gamePrefix, in: rawIdentifier) else {
            return
        }
        AppLog.touchbar.debug("Touch Bar instance tapped: \(gameId)")
        container?.core.selectedGameManager.setSelectedGame(gameId)
        (cachedItems[Identifier.gamePicker.rawValue] as? NSPopoverTouchBarItem)?.dismissPopover(nil)
        refresh()
    }

    /// Opens the settings window and, when an instance is selected, jumps
    /// straight to that instance's advanced settings tab.
    @objc func openInstanceSettingsFromTouchBar() {
        if let selectedId = container?.core.selectedGameManager.selectedGameId {
            container?.core.selectedGameManager.setSelectedGameAndOpenAdvancedSettings(selectedId)
        }
        openSettingsAction?()
    }
}
