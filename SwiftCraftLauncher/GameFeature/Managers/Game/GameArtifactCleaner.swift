//
//  GameArtifactCleaner.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Removes the database record and profile directory left behind by a
/// cancelled game installation.
@MainActor
enum GameArtifactCleaner {
    static func cleanupCancelledGame(gameName: String, gameRepository: GameRepository?) async {
        let trimmedName = gameName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        try? await gameRepository?.deleteGamesByName(trimmedName)

        await Task.detached(priority: .utility) {
            let profileDirectory = AppPaths.profileDirectory(gameName: trimmedName)
            guard FileManager.default.fileExists(atPath: profileDirectory.path) else { return }

            do {
                try MinecraftFileManager.cleanupGameDirectories(gameName: trimmedName)
                AppLog.game.info("Deleted cancelled game folder: \(profileDirectory.path)")
            } catch {
                AppLog.game.error("Failed to delete game folder: \(error.localizedDescription)")
            }
        }.value
    }
}
