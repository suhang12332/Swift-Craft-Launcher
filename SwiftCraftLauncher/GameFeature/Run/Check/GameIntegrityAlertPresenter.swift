//
//  GameIntegrityAlertPresenter.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// The action selected for a failed pre-launch integrity check.
enum GameIntegrityChoice: AlertChoice {
    case ignore
    case repair
    case cancel
}

/// Presents integrity problems found before launching a game.
@MainActor
@Observable
final class GameIntegrityAlertPresenter: AlertPresenter<GameIntegrityChoice> {
    private(set) var errors: [GlobalError] = []

    var message: String {
        errors.map { $0.message ?? $0.localizedDescription }.joined(separator: "\n")
    }

    func requestUserChoice(for errors: [GlobalError]) async -> GameIntegrityChoice {
        self.errors = errors
        return await requestUserChoice()
    }
}
