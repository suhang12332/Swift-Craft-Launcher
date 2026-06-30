//
//  GameNameValidator.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Validates game names to prevent duplicates during creation.
@MainActor
class GameNameValidator: ObservableObject {
    @Published var gameName: String = ""
    @Published var isGameNameDuplicate: Bool = false

    private let gameSetupService: GameSetupUtil

    init(gameSetupService: GameSetupUtil) {
        self.gameSetupService = gameSetupService
    }

    /// Validates whether the current game name is a duplicate.
    func validateGameName() async {
        guard !gameName.isEmpty else {
            isGameNameDuplicate = false
            return
        }

        let isDuplicate = await gameSetupService.checkGameNameDuplicate(gameName)
        if isDuplicate != isGameNameDuplicate {
            isGameNameDuplicate = isDuplicate
        }
    }

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
