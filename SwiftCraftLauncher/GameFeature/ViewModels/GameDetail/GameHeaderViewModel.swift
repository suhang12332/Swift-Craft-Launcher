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

    func performRename(gameId: String, currentName _: String, gameRepository: GameRepository) async {
        guard !isRenaming else { return }
        isRenaming = true
        defer { isRenaming = false }

        do {
            let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            try await gameRepository.renameGame(id: gameId, to: trimmedName)
        } catch {
            DIContainer.shared.core.errorHandler.handle(error)
        }
    }
}
