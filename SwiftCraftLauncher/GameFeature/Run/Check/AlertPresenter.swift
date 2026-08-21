//
//  AlertPresenter.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A choice the user makes when an alert is shown.
protocol AlertChoice: Sendable {
    /// The choice that represents cancelling / dismissing the alert.
    static var cancel: Self { get }
}

/// Generic base class for presenters that show a confirmation alert and suspend until the user decides.
@MainActor
@Observable
class AlertPresenter<Choice: AlertChoice> {
    private(set) var isPresented = false
    private var continuation: CheckedContinuation<Choice, Never>?

    init() { }

    func requestUserChoice() async -> Choice {
        if let continuation {
            continuation.resume(returning: Choice.cancel)
            self.continuation = nil
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            isPresented = true
        }
    }

    func resolve(_ choice: Choice) {
        guard let continuation else { return }
        self.continuation = nil
        isPresented = false
        continuation.resume(returning: choice)
    }

    func dismissIfNeeded(as choice: Choice = .cancel) {
        guard continuation != nil else { return }
        resolve(choice)
    }
}
