//
//  AuthlibInjectorMissingPresenter.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A choice the user makes when authlib-injector is missing.
enum AuthlibInjectorMissingChoice {
    /// Continue launch without the `-javaagent` argument.
    case continueWithoutInjector
    /// Dismiss the prompt and cancel the launch.
    case cancel
}

/// Presents a confirmation prompt when authlib-injector is missing during launch.
///
/// The main window observes ``isPresented`` and displays a modal. The launch
/// flow suspends until the user makes a choice or the prompt is dismissed.
@MainActor
final class AuthlibInjectorMissingPresenter: ObservableObject {
    @Published private(set) var isPresented = false

    private var continuation: CheckedContinuation<AuthlibInjectorMissingChoice, Never>?

    init() { }

    func requestUserChoice() async -> AuthlibInjectorMissingChoice {
        if let continuation {
            continuation.resume(returning: .cancel)
            self.continuation = nil
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            isPresented = true
        }
    }

    func resolve(_ choice: AuthlibInjectorMissingChoice) {
        guard let continuation else { return }
        self.continuation = nil
        isPresented = false
        continuation.resume(returning: choice)
    }

    func dismissIfNeeded(as choice: AuthlibInjectorMissingChoice = .cancel) {
        guard continuation != nil else { return }
        resolve(choice)
    }
}

/// An error indicating the user cancelled the launch due to a missing authlib-injector.
struct AuthlibInjectorLaunchCancelled: Error { }
