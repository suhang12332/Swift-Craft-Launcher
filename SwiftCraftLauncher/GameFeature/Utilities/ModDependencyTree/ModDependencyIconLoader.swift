//
//  ModDependencyIconLoader.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import Foundation
import ModDependencyGraphKit

extension ModDependencyIconLoader {
    /// Loads the icon of a game, which can be a local profile file or a remote
    /// URL depending on how the game was created.
    @MainActor
    static func loadGameIcon(for game: GameVersionInfo) async -> NSImage? {
        let trimmed = game.gameIcon.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" || scheme == "data" {
            return await loadImage(from: url)
        }

        let url = AppPaths.profileDirectory(gameName: game.gameName)
            .appendingPathComponent(trimmed)
        return NSImage(contentsOf: url)
    }
}
