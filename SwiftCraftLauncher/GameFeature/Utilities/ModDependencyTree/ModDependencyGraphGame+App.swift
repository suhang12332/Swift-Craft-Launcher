//
//  ModDependencyGraphGame+App.swift
//  GameFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import ModDependencyGraphKit

extension ModDependencyGraphGame {
    /// Builds the graph root card data from a launcher game record.
    @MainActor
    init(game: GameVersionInfo, icon: NSImage?) {
        let loaderName = GameLoader(rawValue: game.modLoader.lowercased())?.labelName ?? game.modLoader
        let detail = [game.gameVersion, loaderName, game.modVersion]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")

        self.init(
            title: game.gameName,
            detail: detail,
            icon: icon,
        )
    }
}
