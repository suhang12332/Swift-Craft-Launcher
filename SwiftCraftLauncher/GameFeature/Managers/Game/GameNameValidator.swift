//
//  GameNameValidator.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Validates game names to prevent duplicates during creation.
@MainActor
@Observable
class GameNameValidator {
    var gameName: String = ""
    var isGameNameDuplicate: Bool = false

    init() { }

    /// Sets a default game name only when the current name is empty.
    /// - Parameter name: The default name to set.
    func setDefaultName(_ name: String) {
        if gameName.isEmpty {
            gameName = name
        }
    }

    func reset() {
        gameName = ""
        isGameNameDuplicate = false
    }

    /// A Boolean value indicating whether the form input is valid.
    var isFormValid: Bool {
        !gameName.isEmpty && !isGameNameDuplicate
    }
}
