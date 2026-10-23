//
//  InstallTaskCoordinator.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

/// Owns the in-flight installation task and its cancellation bookkeeping.
///
/// Game creation, modpack import, and modpack download all need the same
/// "one installation at a time, cancel before restarting" semantics; only the
/// cleanup that follows a cancellation differs per flow.
@MainActor
@Observable
final class InstallTaskCoordinator {
    /// Whether an installation task is currently running.
    private(set) var isRunning = false

    /// Whether the last task was cancelled and has not finished cleaning up yet.
    private(set) var isCancelling = false

    private var task: Task<Void, Never>?
    private var token = UUID()

    /// Starts `operation`, cancelling any task that is still running.
    /// - Parameters:
    ///   - onFinish: Called on the main actor when the task finishes, unless a
    ///     newer task has superseded it.
    ///   - operation: The installation work to run.
    func start(
        onFinish: (@MainActor () async -> Void)? = nil,
        operation: @escaping @MainActor () async -> Void,
    ) {
        task?.cancel()

        let token = UUID()
        self.token = token
        isCancelling = false
        isRunning = true

        let newTask = Task { await operation() }
        task = newTask

        Task { [weak self] in
            _ = await newTask.value
            guard let self, self.token == token else { return }
            task = nil
            isRunning = false
            await onFinish?()
        }
    }

    /// Cancels the running task. Safe to call repeatedly.
    func cancel() {
        isCancelling = true
        task?.cancel()
        task = nil
        isRunning = false
    }

    func finish() {
        task = nil
        token = UUID()
        isRunning = false
        isCancelling = false
    }
}
