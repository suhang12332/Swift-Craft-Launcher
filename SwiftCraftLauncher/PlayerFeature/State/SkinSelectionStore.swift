//
//  SkinSelectionStore.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Manages the currently selected player for skin operations.
@Observable
class SkinSelectionStore {
    /// The identifier of the selected player.
    var selectedPlayerId: String?

    /// Updates the selected player identifier.
    ///
    /// - Parameter id: The identifier to select, or `nil` to clear the selection.
    func select(_ id: String?) {
        if selectedPlayerId != id { selectedPlayerId = id }
    }
}
