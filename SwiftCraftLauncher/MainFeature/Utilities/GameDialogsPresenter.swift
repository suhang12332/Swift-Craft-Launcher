//
//  GameDialogsPresenter.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Manages presentation state for main-window game dialogs such as mod-pack export and deletion confirmation.
@MainActor
final class GameDialogsPresenter: ObservableObject {
    static let shared = GameDialogsPresenter()

    @Published var gameForExport: GameVersionInfo?
    @Published var gamePendingDeletion: GameVersionInfo?

    private init() { }

    func presentModPackExport(for game: GameVersionInfo) {
        gameForExport = game
    }

    func requestGameDeletion(of game: GameVersionInfo) {
        gamePendingDeletion = game
    }
}
