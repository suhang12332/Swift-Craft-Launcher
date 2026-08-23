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
    var newName: String = ""

    init() { }

    func isNameValid(newName: String, currentName: String, gameId: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != currentName else { return false }
        if DIContainer.shared.core.gameProcessManager.isGameRunningForAnyUser(gameId: gameId) { return false }
        return !FileManager.default.fileExists(
            atPath: AppPaths.profileDirectory(gameName: trimmed).path
        )
    }

    func performRename(gameId: String, currentName: String, gameRepository: GameRepository) async {
        do {
            try await gameRepository.renameGame(id: gameId, to: newName.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            DIContainer.shared.core.errorHandler.handle(error)
        }
    }
}
