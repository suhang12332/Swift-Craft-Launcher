//
//  IconRefreshNotifier.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Combine

/// Publishes notifications when game icons need to refresh.
final class IconRefreshNotifier: ObservableObject {
    static let shared = IconRefreshNotifier()

    /// The subject that emits game names to refresh, where `nil` refreshes all icons.
    private let refreshSubject = PassthroughSubject<String?, Never>()

    /// A publisher that emits the game name to refresh.
    var refreshPublisher: AnyPublisher<String?, Never> {
        refreshSubject.eraseToAnyPublisher()
    }

    private init() {}

    /// Notifies observers to refresh the icon for a specific game.
    /// - Parameter gameName: The game name, or `nil` to refresh all icons.
    func notifyRefresh(for gameName: String?) {
        refreshSubject.send(gameName)
    }

    /// Notifies observers to refresh all icons.
    func notifyRefreshAll() {
        refreshSubject.send(nil)
    }
}
