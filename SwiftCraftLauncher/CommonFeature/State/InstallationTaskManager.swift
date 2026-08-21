//
//  InstallationTaskManager.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Keeps main-actor installation tasks alive after their presentation sheet is hidden.
///
/// Both the manager and the stored operations are main-actor isolated so an operation
/// can safely update its view model while it outlives the presenting view.
@MainActor
final class InstallationTaskManager {
    static let shared = InstallationTaskManager()

    private var tasks: [UUID: Task<Void, Never>] = [:]

    private init() { }

    /// Starts a main-actor installation operation that can outlive its presenting view.
    func start(operation: @escaping @MainActor @Sendable () async -> Void) -> UUID {
        let id = UUID()
        tasks[id] = Task { @MainActor [weak self] in
            await operation()
            self?.tasks[id] = nil
        }
        return id
    }

    /// Cancels and removes an installation operation.
    func cancel(_ id: UUID?) {
        guard let id else { return }
        tasks.removeValue(forKey: id)?.cancel()
    }

    /// Removes a completed operation without cancelling it.
    func finish(_ id: UUID?) {
        guard let id else { return }
        tasks[id] = nil
    }
}
