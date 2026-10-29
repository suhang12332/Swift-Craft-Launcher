//
//  GameIntegrityChecker.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Performs the minimum pre-launch integrity check and repair.
enum GameIntegrityChecker {
    static func check(game: GameVersionInfo) async -> GlobalError? {
        let javaPath = game.javaPath
        let canRunJava = await Task.detached(priority: .userInitiated) {
            DIContainer.shared.system.javaManager.canJavaRun(at: javaPath)
        }.value

        guard !canRunJava else { return nil }
        return .gameLaunch(i18nKey: "game_launch.integrity.java_unusable")
    }
}
