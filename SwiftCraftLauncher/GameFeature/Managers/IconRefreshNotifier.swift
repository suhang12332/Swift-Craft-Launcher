//
//  IconRefreshNotifier.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

/// Publishes notifications when game icons need to refresh.
///
/// Consumers obtain a stream via ``refreshRequests()`` and iterate it with
/// `for await`; the stream terminates automatically when the consuming task is
/// cancelled, removing the underlying continuation.
@MainActor
@Observable
final class IconRefreshNotifier {
    private var continuations: [UUID: AsyncStream<String?>.Continuation] = [:]

    init() { }

    /// A stream of icon refresh requests, where a `nil` game name means refresh all icons.
    func refreshRequests() -> AsyncStream<String?> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.continuations[id] = nil }
            }
        }
    }

    /// Notifies observers to refresh the icon for a specific game.
    /// - Parameter gameName: The game name, or `nil` to refresh all icons.
    func notifyRefresh(for gameName: String?) {
        for continuation in continuations.values {
            continuation.yield(gameName)
        }
    }
}
