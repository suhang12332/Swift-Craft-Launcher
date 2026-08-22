//
//  TouchBarSupport.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import Observation
import SwiftUI

/// Attaches the app-specific Touch Bar to the window that hosts the modified view.
extension View {
    func touchBarSupport() -> some View {
        background(TouchBarInstaller())
    }
}

/// A zero-size AppKit view that reports when it moves into a window.
private final class TouchBarAttachmentView: NSView {
    var onWindowChanged: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            onWindowChanged?(window)
        }
    }
}

/// A button with a fixed minimum width whose content hugging is low, so the
/// Touch Bar distributes the remaining strip width evenly between all instance
/// buttons instead of sizing each by its title.
private final class TouchBarInstanceButton: NSButton {
    var minimumWidth: CGFloat = 52

    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width = max(size.width, minimumWidth)
        return size
    }
}

/// Installs and keeps the launcher Touch Bar in sync with SwiftUI state.
private struct TouchBarInstaller: NSViewRepresentable {
    @Environment(DIContainer.self)
    private var container
    @Environment(GameRepository.self)
    private var gameRepository
    @Environment(GameLaunchUseCase.self)
    private var gameLaunchUseCase
    @Environment(PlayerListViewModel.self)
    private var playerListViewModel
    @Environment(\.openSettings)
    private var openSettings

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = TouchBarAttachmentView()
        view.onWindowChanged = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(
            container: container,
            gameRepository: gameRepository,
            gameLaunchUseCase: gameLaunchUseCase,
            playerListViewModel: playerListViewModel,
        ) {
            openSettings()
        }
        if let window = nsView.window {
            context.coordinator.attach(to: window)
        }
    }
}

extension TouchBarInstaller {
    @MainActor
    final class Coordinator {
        let controller = TouchBarController()
        private var latestConfiguration: TouchBarConfiguration?

        func attach(to window: NSWindow) {
            controller.install(on: window)
            if let latestConfiguration {
                controller.update(with: latestConfiguration)
            }
        }

        func update(
            container: DIContainer,
            gameRepository: GameRepository,
            gameLaunchUseCase: GameLaunchUseCase,
            playerListViewModel: PlayerListViewModel,
            openSettings: @escaping @MainActor () -> Void,
        ) {
            let configuration = TouchBarConfiguration(
                container: container,
                gameRepository: gameRepository,
                gameLaunchUseCase: gameLaunchUseCase,
                playerListViewModel: playerListViewModel,
                openSettings: openSettings,
            )
            latestConfiguration = configuration
            controller.update(with: configuration)
        }
    }
}

/// The state and actions required to render the launcher Touch Bar.
private struct TouchBarConfiguration {
    let container: DIContainer
    let gameRepository: GameRepository
    let gameLaunchUseCase: GameLaunchUseCase
    let playerListViewModel: PlayerListViewModel
    let openSettings: @MainActor () -> Void
}

/// Owns the main window Touch Bar and keeps its items in sync with app state.
@MainActor
private final class TouchBarController: NSObject, NSTouchBarDelegate {
    private enum Identifier {
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

    private weak var window: NSWindow?
    private let touchBar = NSTouchBar()
    private var cachedItems: [String: NSTouchBarItem] = [:]
    private var playerPickerTouchBar: NSTouchBar?
    private var playerPickerItems: [String: NSTouchBarItem] = [:]
    private var gamePickerTouchBar: NSTouchBar?
    private var gamePickerItems: [String: NSTouchBarItem] = [:]
    private var gamePickerIDs: [String] = []
    private var gamePickerGames: [GameVersionInfo] = []
    private var playerPickerIDs: [String] = []

    private var container: DIContainer?
    private var gameRepository: GameRepository?
    private var gameLaunchUseCase: GameLaunchUseCase?
    private var playerListViewModel: PlayerListViewModel?
    private var openSettingsAction: (@MainActor () -> Void)?

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

    private func refresh() {
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

    private func updatePlayerPicker(currentPlayer: Player?) {
        let item = mainItem(Identifier.playerPicker) {
            let picker = NSPopoverTouchBarItem(identifier: Identifier.playerPicker)
            picker.showsCloseButton = true
            picker.collapsedRepresentationLabel = currentPlayer?.name ?? "menu.player.list".localized()
            return picker
        }
        guard let picker = item as? NSPopoverTouchBarItem else { return }

        picker.collapsedRepresentationLabel = currentPlayer?.name ?? "menu.player.list".localized()

        let playerIDs = playerListViewModel?.players.map(\.id) ?? []
        if playerIDs != playerPickerIDs {
            playerPickerIDs = playerIDs

            let childBar: NSTouchBar
            if let existing = playerPickerTouchBar {
                childBar = existing
            } else {
                let bar = NSTouchBar()
                bar.delegate = self
                playerPickerTouchBar = bar
                childBar = bar
            }
            childBar.defaultItemIdentifiers = playerIDs.map { Identifier.player($0) }
            playerPickerItems.removeAll()
            picker.popoverTouchBar = childBar
        } else if let bar = playerPickerTouchBar {
            picker.popoverTouchBar = bar
        }
    }

    private func updateGamePicker(games: [GameVersionInfo], selectedGame: GameVersionInfo?) {
        let item = mainItem(Identifier.gamePicker) {
            let picker = NSPopoverTouchBarItem(identifier: Identifier.gamePicker)
            picker.showsCloseButton = true
            picker.collapsedRepresentationLabel = selectedGame.map { touchBarTitle(for: $0.gameName) }
                ?? "global_resource.select_game".localized()
            return picker
        }
        guard let picker = item as? NSPopoverTouchBarItem else { return }

        refreshGamePickerSelection(games: games, selectedGame: selectedGame, picker: picker)

        let gameIDs = games.map(\.id)
        if gameIDs != gamePickerIDs {
            gamePickerIDs = gameIDs
            gamePickerGames = games

            let childBar: NSTouchBar
            if let existing = gamePickerTouchBar {
                childBar = existing
            } else {
                let bar = NSTouchBar()
                bar.delegate = self
                gamePickerTouchBar = bar
                childBar = bar
            }
            childBar.defaultItemIdentifiers = games.map { Identifier.game($0.id) }
            gamePickerItems.removeAll()
            picker.popoverTouchBar = childBar
            AppLog.touchbar.debug(
                "Game picker rebuilt: \(gameIDs.count) identifiers [\(gameIDs.joined(separator: ","))]",
            )
        } else if let bar = gamePickerTouchBar {
            picker.popoverTouchBar = bar
        }
    }

    /// Updates the collapsed representation and the check mark on each instance
    /// entry without rebuilding the expanded list.
    private func refreshGamePickerSelection(
        games: [GameVersionInfo],
        selectedGame: GameVersionInfo?,
        picker: NSPopoverTouchBarItem,
    ) {
        picker.collapsedRepresentationLabel = selectedGame.map { touchBarTitle(for: $0.gameName) }
            ?? "global_resource.select_game".localized()
        picker.collapsedRepresentationImage = symbolImage(
            "gamecontroller.fill",
            accessibilityDescription: selectedGame?.gameName,
        )

        for (rawKey, item) in gamePickerItems {
            guard let gameId = Identifier.id(afterPrefix: Identifier.gamePrefix, in: rawKey),
                  let game = games.first(where: { $0.id == gameId }),
                  let button = (item as? NSCustomTouchBarItem)?.view as? NSButton else {
                continue
            }
            button.attributedTitle = instanceButtonTitle(for: game, isSelected: game.id == selectedGame?.id)
        }
    }

    /// Attributed title for an instance button.
    ///
    /// The paragraph style truncates the tail, so the text adapts to whatever
    /// width the button is finally assigned; the leading check mark marks the
    /// currently selected instance.
    private func instanceButtonTitle(for game: GameVersionInfo, isSelected: Bool) -> NSAttributedString {
        let name = isSelected ? "✓ " + game.gameName : game.gameName
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = .center
        let font = NSFont.systemFont(ofSize: 15, weight: isSelected ? .semibold : .regular)
        return NSAttributedString(string: name, attributes: [
            .font: font,
            .paragraphStyle: paragraph,
            .foregroundColor: NSColor.labelColor,
        ])
    }

    /// Returns a title truncated so that several instances fit on the Touch Bar.
    private func touchBarTitle(for name: String, maxCharacters: Int = 14) -> String {
        guard name.count > maxCharacters else { return name }
        return String(name.prefix(maxCharacters)) + "…"
    }

    private func symbolImage(_ name: String, accessibilityDescription: String? = nil) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription) ?? NSImage()
    }

    private func updatePlayStopItem(selectedGame: GameVersionInfo?, currentPlayer: Player?) {
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

    private func makeMainItem(for identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case Identifier.playerPicker:
            let picker = NSPopoverTouchBarItem(identifier: identifier)
            picker.showsCloseButton = true
            picker.collapsedRepresentationLabel = "menu.player.list".localized()
            cachedItems[identifier.rawValue] = picker
            return picker
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

    private func mainItem(_ identifier: NSTouchBarItem.Identifier, factory: () -> NSTouchBarItem) -> NSTouchBarItem {
        if let item = cachedItems[identifier.rawValue] {
            return item
        }
        let item = factory()
        cachedItems[identifier.rawValue] = item
        return item
    }

    private func makePlayerPickerItem(for identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if let item = playerPickerItems[identifier.rawValue] {
            return item
        }
        guard let playerId = Identifier.id(afterPrefix: Identifier.playerPrefix, in: identifier.rawValue),
              let player = playerListViewModel?.players.first(where: { $0.id == playerId }) else {
            return nil
        }

        let item = NSButtonTouchBarItem(
            identifier: identifier,
            title: player.name,
            target: self,
            action: #selector(selectPlayer(_:)),
        )
        item.customizationLabel = player.name
        playerPickerItems[identifier.rawValue] = item
        return item
    }

    private func makeGamePickerItem(for identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if let item = gamePickerItems[identifier.rawValue] {
            return item
        }
        guard let gameId = Identifier.id(afterPrefix: Identifier.gamePrefix, in: identifier.rawValue) else {
            AppLog.touchbar.error("Cannot parse game id from \(identifier.rawValue)")
            return nil
        }
        guard let game = gamePickerGames.first(where: { $0.id == gameId })
            ?? gameRepository?.games.first(where: { $0.id == gameId }) else {
            AppLog.touchbar.error("Cannot create game item for id=\(gameId)")
            return nil
        }

        let isSelected = game.id == container?.core.selectedGameManager.selectedGameId
        let button = TouchBarInstanceButton(title: "", target: self, action: #selector(selectGame(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(identifier.rawValue)
        button.bezelStyle = .texturedRounded
        button.attributedTitle = instanceButtonTitle(for: game, isSelected: isSelected)
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        button.toolTip = game.gameName

        let item = NSCustomTouchBarItem(identifier: identifier)
        item.view = button
        item.customizationLabel = game.gameName
        gamePickerItems[identifier.rawValue] = item
        return item
    }

    private func resolveSelectedGame(in games: [GameVersionInfo]) -> GameVersionInfo? {
        guard let selectedId = container?.core.selectedGameManager.selectedGameId else {
            return nil
        }
        return games.first { $0.id == selectedId }
    }

    @objc private func toggleSelectedGame() {
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

    @objc private func selectPlayer(_ sender: NSButton) {
        guard let rawIdentifier = sender.identifier?.rawValue,
              let playerId = Identifier.id(afterPrefix: Identifier.playerPrefix, in: rawIdentifier) else {
            return
        }
        playerListViewModel?.setCurrentPlayer(byID: playerId)
        (cachedItems[Identifier.playerPicker.rawValue] as? NSPopoverTouchBarItem)?.dismissPopover(nil)
        refresh()
    }

    @objc private func selectGame(_ sender: NSButton) {
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
    @objc private func openInstanceSettingsFromTouchBar() {
        if let selectedId = container?.core.selectedGameManager.selectedGameId {
            container?.core.selectedGameManager.setSelectedGameAndOpenAdvancedSettings(selectedId)
        }
        openSettingsAction?()
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
