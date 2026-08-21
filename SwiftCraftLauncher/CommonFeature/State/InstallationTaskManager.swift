//
//  InstallationTaskManager.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

struct InstallationProgress: Identifiable {
    let id: UUID
    var title: String
    var completed: Int64 = 0
    var total: Int64 = 0
    var currentFile = ""

    var fraction: Double? {
        guard total > 0 else { return nil }
        return min(max(Double(completed) / Double(total), 0), 1)
    }
}

/// Keeps main-actor installation tasks alive after their presentation sheet is hidden.
///
/// Both the manager and the stored operations are main-actor isolated so an operation
/// can safely update its view model while it outlives the presenting view.
@MainActor
@Observable
final class InstallationTaskManager {
    static let shared = InstallationTaskManager()

    private var tasks: [UUID: Task<Void, Never>] = [:]
    private(set) var progress: [UUID: InstallationProgress] = [:]

    private init() { }

    /// Starts a main-actor installation operation that can outlive its presenting view.
    func start(operation: @escaping @MainActor @Sendable () async -> Void) -> UUID {
        let id = UUID()
        progress[id] = InstallationProgress(id: id, title: "common.loading".localized())
        tasks[id] = Task { @MainActor [weak self] in
            await operation()
            self?.remove(id)
        }
        return id
    }

    /// Updates the user-visible progress for an active installation.
    func updateProgress(_ id: UUID?, completed: Int64, total: Int64, currentFile: String = "") {
        guard let id, var item = progress[id] else { return }
        item.completed = completed
        item.total = total
        item.currentFile = currentFile
        progress[id] = item
    }

    /// Cancels and removes an installation operation.
    func cancel(_ id: UUID?) {
        guard let id else { return }
        tasks.removeValue(forKey: id)?.cancel()
        progress[id] = nil
    }

    /// Removes a completed operation without cancelling it.
    func finish(_ id: UUID?) {
        guard let id else { return }
        remove(id)
    }

    private func remove(_ id: UUID) {
        tasks[id] = nil
        progress[id] = nil
    }
}
