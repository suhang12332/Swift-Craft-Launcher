//
//  SidebarViewModel.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Manages sidebar state and icon refresh triggers for game items.
@MainActor
@Observable
final class SidebarViewModel {
    private(set) var iconRefreshTriggers: [String: UUID] = [:]

    private var observationTask: Task<Void, Never>?

    init() { }

    /// Returns the current refresh trigger UUID for a game, or a new one if none exists.
    /// - Parameter gameName: The name of the game to query.
    /// - Returns: A UUID representing the current refresh state for the game.
    func refreshTrigger(for gameName: String) -> UUID {
        iconRefreshTriggers[gameName] ?? UUID()
    }

    /// Subscribes to icon refresh events and updates triggers when the view appears.
    /// - Parameter games: The list of games currently displayed in the sidebar.
    func onAppear(games: [GameVersionInfo]) {
        ensureTriggers(for: games)

        observationTask?.cancel()
        let notifier = DIContainer.shared.ui.iconRefreshNotifier
        observationTask = Task { @MainActor [weak self] in
            for await refreshedGameName in notifier.refreshRequests() {
                guard let self else { return }
                applyIconRefresh(refreshedGameName)
            }
        }
    }

    /// Cancels the icon refresh subscription when the view disappears.
    func onDisappear() {
        observationTask?.cancel()
        observationTask = nil
    }

    private func applyIconRefresh(_ refreshedGameName: String?) {
        if let gameName = refreshedGameName {
            iconRefreshTriggers[gameName] = UUID()
        } else {
            for gameName in iconRefreshTriggers.keys {
                iconRefreshTriggers[gameName] = UUID()
            }
        }
    }

    /// Ensures refresh triggers exist for the updated game list.
    /// - Parameter newGames: The updated list of games.
    func onGamesChanged(_ newGames: [GameVersionInfo]) {
        ensureTriggers(for: newGames)
    }

    private func ensureTriggers(for games: [GameVersionInfo]) {
        for game in games where iconRefreshTriggers[game.gameName] == nil {
            iconRefreshTriggers[game.gameName] = UUID()
        }
    }
}
