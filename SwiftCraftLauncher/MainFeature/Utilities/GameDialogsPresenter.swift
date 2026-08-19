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
@Observable
final class GameDialogsPresenter {
    var gameForExport: GameVersionInfo?
    var gamePendingDeletion: GameVersionInfo?
    var gamePendingLoaderUpdate: GameVersionInfo?

    init() { }

    func presentModPackExport(for game: GameVersionInfo) {
        gameForExport = game
    }

    func requestGameDeletion(of game: GameVersionInfo) {
        gamePendingDeletion = game
    }

    func presentLoaderUpdate(for game: GameVersionInfo) {
        gamePendingLoaderUpdate = game
    }
}
