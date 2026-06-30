//
//  SkinSelectionStore.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Manages the currently selected player for skin operations.
class SkinSelectionStore: ObservableObject {
    /// The identifier of the selected player.
    @Published var selectedPlayerId: String?

    /// Updates the selected player identifier.
    ///
    /// - Parameter id: The identifier to select, or `nil` to clear the selection.
    func select(_ id: String?) {
        if selectedPlayerId != id { selectedPlayerId = id }
    }
}
