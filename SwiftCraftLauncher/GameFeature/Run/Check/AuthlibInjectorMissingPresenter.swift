//
//  AuthlibInjectorMissingPresenter.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A choice the user makes when authlib-injector is missing.
enum AuthlibInjectorMissingChoice: AlertChoice {
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
@Observable
final class AuthlibInjectorMissingPresenter: AlertPresenter<AuthlibInjectorMissingChoice> { }

/// An error indicating the user cancelled the launch due to a missing authlib-injector.
struct AuthlibInjectorLaunchCancelled: Error { }
