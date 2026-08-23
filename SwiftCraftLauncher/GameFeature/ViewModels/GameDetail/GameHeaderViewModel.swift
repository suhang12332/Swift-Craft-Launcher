//
//  GameHeaderViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

@MainActor
@Observable
final class GameHeaderViewModel {
    var newName = ""
    var isRenaming = false

    func isNameValid(newName: String, currentName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != currentName else { return false }
        return !FileManager.default.fileExists(
            atPath: AppPaths.profileDirectory(gameName: trimmed).path,
        )
    }
}
