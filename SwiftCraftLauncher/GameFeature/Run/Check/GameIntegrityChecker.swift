//
//  GameIntegrityChecker.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Performs the minimum pre-launch integrity check and repair.
enum GameIntegrityChecker {
    static func check(game: GameVersionInfo) -> GlobalError? {

        guard DIContainer.shared.system.javaManager.canJavaRun(at: game.javaPath) else {
            return .gameLaunch(i18nKey: "game_launch.integrity.java_unusable")
        }

        return nil
    }
}
