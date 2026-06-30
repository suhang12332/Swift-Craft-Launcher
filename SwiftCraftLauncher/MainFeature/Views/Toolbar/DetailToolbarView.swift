//
//  DetailToolbarView.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Provides context-sensitive toolbar content for the detail panel.
public struct DetailToolbarView: ToolbarContent {
    @EnvironmentObject private var filterState: ResourceFilterState
    @EnvironmentObject private var detailState: ResourceDetailState
    @EnvironmentObject private var gameRepository: GameRepository

    private var currentGame: GameVersionInfo? {
        if case .game(let gameId) = detailState.selectedItem {
            return gameRepository.getGame(by: gameId)
        }
        return nil
    }

    public var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            switch detailState.selectedItem {
            case .game:
                if let game = currentGame {
                    GameToolbarItems(game: game)
                }
            case .resource:
                ResourceToolbarItems()
            }
        }
    }
}
