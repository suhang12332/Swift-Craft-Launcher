//
//  MemoryPressureAlertPresenter.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A choice the user makes when a memory pressure warning is shown.
enum MemoryPressureChoice {
    /// Proceed with the launch despite elevated memory pressure.
    case continueAnyway
    /// Cancel the launch.
    case cancel
}

/// Presents a confirmation prompt when the system is under memory pressure before launch.
///
/// The main window observes ``isPresented`` and displays a modal. The launch
/// flow suspends until the user makes a choice or the prompt is dismissed.
@MainActor
@Observable
final class MemoryPressureAlertPresenter {
    private(set) var isPresented = false
    private(set) var pressureLevel: MemoryPressureLevel = .normal

    private var continuation: CheckedContinuation<MemoryPressureChoice, Never>?

    init() { }

    func requestUserChoice(for level: MemoryPressureLevel) async -> MemoryPressureChoice {
        if let continuation {
            continuation.resume(returning: .cancel)
            self.continuation = nil
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.pressureLevel = level
            isPresented = true
        }
    }

    func resolve(_ choice: MemoryPressureChoice) {
        guard let continuation else { return }
        self.continuation = nil
        isPresented = false
        continuation.resume(returning: choice)
    }
}
