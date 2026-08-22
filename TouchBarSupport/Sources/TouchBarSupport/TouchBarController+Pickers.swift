//
//  TouchBarController+Pickers.swift
//  TouchBarSupport
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit

extension TouchBarController {
    func updateGamePicker(instances: [TouchBarInstance], selectedGame: TouchBarInstance?) {
        let item = mainItem(Identifier.gamePicker) {
            let picker = NSPopoverTouchBarItem(identifier: Identifier.gamePicker)
            picker.showsCloseButton = true
            picker.collapsedRepresentationLabel = selectedGame.map { touchBarTitle(for: $0.name) }
                ?? configuration?.strings.selectGame ?? ""
            return picker
        }
        guard let picker = item as? NSPopoverTouchBarItem else { return }

        refreshGamePickerSelection(instances: instances, selectedGame: selectedGame, picker: picker)

        let gameIDs = instances.map(\.id)
        if gameIDs != gamePickerIDs {
            gamePickerIDs = gameIDs
            gamePickerInstances = instances

            let childBar: NSTouchBar
            if let existing = gamePickerTouchBar {
                childBar = existing
            } else {
                let bar = NSTouchBar()
                bar.delegate = self
                gamePickerTouchBar = bar
                childBar = bar
            }
            childBar.defaultItemIdentifiers = instances.map { Identifier.game($0.id) }
            gamePickerItems.removeAll()
            picker.popoverTouchBar = childBar
            TouchBarLog.log.debug("Game picker rebuilt: \(gameIDs.count) identifiers [\(gameIDs.joined(separator: ","))]")
        } else if let bar = gamePickerTouchBar {
            picker.popoverTouchBar = bar
        }
    }

    /// Updates the collapsed representation and the check mark on each instance
    /// entry without rebuilding the expanded list.
    func refreshGamePickerSelection(
        instances: [TouchBarInstance],
        selectedGame: TouchBarInstance?,
        picker: NSPopoverTouchBarItem,
    ) {
        picker.collapsedRepresentationLabel = selectedGame.map { touchBarTitle(for: $0.name) }
            ?? configuration?.strings.selectGame ?? ""
        picker.collapsedRepresentationImage = symbolImage(
            "gamecontroller.fill",
            accessibilityDescription: selectedGame?.name,
        )

        for (rawKey, item) in gamePickerItems {
            guard let gameId = Identifier.id(afterPrefix: Identifier.gamePrefix, in: rawKey),
                  let game = instances.first(where: { $0.id == gameId }),
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
    func instanceButtonTitle(for game: TouchBarInstance, isSelected: Bool) -> NSAttributedString {
        let name = isSelected ? "✓ " + game.name : game.name
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
    func touchBarTitle(for name: String, maxCharacters: Int = 14) -> String {
        guard name.count > maxCharacters else { return name }
        return String(name.prefix(maxCharacters)) + "…"
    }

    func makeGamePickerItem(for identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if let item = gamePickerItems[identifier.rawValue] {
            return item
        }
        guard let gameId = Identifier.id(afterPrefix: Identifier.gamePrefix, in: identifier.rawValue) else {
            TouchBarLog.log.error("Cannot parse game id from \(identifier.rawValue)")
            return nil
        }
        guard let game = gamePickerInstances.first(where: { $0.id == gameId }) else {
            TouchBarLog.log.error("Cannot create game item for id=\(gameId)")
            return nil
        }

        let isSelected = game.id == configuration?.currentInstanceID()
        let button = TouchBarInstanceButton(title: "", target: self, action: #selector(selectGame(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(identifier.rawValue)
        button.bezelStyle = .texturedRounded
        button.attributedTitle = instanceButtonTitle(for: game, isSelected: isSelected)
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        button.toolTip = game.name

        let item = NSCustomTouchBarItem(identifier: identifier)
        item.view = button
        item.customizationLabel = game.name
        gamePickerItems[identifier.rawValue] = item
        return item
    }
}
