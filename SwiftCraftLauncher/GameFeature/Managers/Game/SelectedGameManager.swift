//
//  SelectedGameManager.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Shares the currently selected game ID between the main view and settings.
class SelectedGameManager: ObservableObject {
    /// The currently selected game identifier.
    @Published var selectedGameId: String? {
        didSet {
            objectWillChange.send()
        }
    }

    /// Whether the advanced settings tab should be opened.
    @Published var shouldOpenAdvancedSettings: Bool = false {
        didSet {
            objectWillChange.send()
        }
    }

    init() { }

    /// Sets the selected game.
    /// - Parameter gameId: The game identifier, or `nil` to clear the selection.
    func setSelectedGame(_ gameId: String?) {
        selectedGameId = gameId
    }

    /// Clears the current selection and resets the advanced settings flag.
    func clearSelection() {
        selectedGameId = nil
        shouldOpenAdvancedSettings = false
    }

    /// Sets the selected game and flags the advanced settings tab to open.
    /// - Parameter gameId: The game identifier.
    func setSelectedGameAndOpenAdvancedSettings(_ gameId: String?) {
        selectedGameId = gameId
        shouldOpenAdvancedSettings = true
    }
}
