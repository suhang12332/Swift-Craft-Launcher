//
//  TouchBarSupport.swift
//  TouchBarSupport
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import os
import SwiftUI

/// A lightweight view of a game instance for the Touch Bar.
public struct TouchBarInstance: Identifiable, Hashable, Sendable {
    /// The unique identifier of the instance.
    public let id: String
    /// The display name of the instance.
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// User-facing texts rendered by the Touch Bar.
public struct TouchBarStrings: Sendable {
    /// Placeholder shown when no instance is selected.
    public var selectGame: String
    /// Title of the instance-settings button.
    public var instanceSettings: String

    public init(selectGame: String, instanceSettings: String) {
        self.selectGame = selectGame
        self.instanceSettings = instanceSettings
    }
}

/// The data sources and actions the app provides to the Touch Bar.
///
/// All state is supplied through closures so the package never depends on
/// application types; reading observable state inside the closures keeps the
/// Touch Bar in sync through Observation tracking.
public struct TouchBarSupportConfiguration {
    /// The name of the currently active player, or nil when none is signed in.
    public var currentPlayerName: @MainActor () -> String?
    /// All available game instances.
    public var instances: @MainActor () -> [TouchBarInstance]
    /// The identifier of the currently selected instance, or nil.
    public var currentInstanceID: @MainActor () -> String?
    /// Whether the instance is currently running for the active player.
    public var isRunning: @MainActor (String) -> Bool
    /// Whether the instance is currently launching for the active player.
    public var isLaunching: @MainActor (String) -> Bool
    /// Called when the user picks an instance from the picker.
    public var onSelectInstance: @MainActor (String) -> Void
    /// Called when the user taps the play/stop button.
    public var onPlayStop: @MainActor () -> Void
    /// Called when the user taps the instance-settings button.
    public var onOpenSettings: @MainActor () -> Void
    /// Localized texts.
    public var strings: TouchBarStrings

    public init(
        currentPlayerName: @escaping @MainActor () -> String?,
        instances: @escaping @MainActor () -> [TouchBarInstance],
        currentInstanceID: @escaping @MainActor () -> String?,
        isRunning: @escaping @MainActor (String) -> Bool,
        isLaunching: @escaping @MainActor (String) -> Bool,
        onSelectInstance: @escaping @MainActor (String) -> Void,
        onPlayStop: @escaping @MainActor () -> Void,
        onOpenSettings: @escaping @MainActor () -> Void,
        strings: TouchBarStrings,
    ) {
        self.currentPlayerName = currentPlayerName
        self.instances = instances
        self.currentInstanceID = currentInstanceID
        self.isRunning = isRunning
        self.isLaunching = isLaunching
        self.onSelectInstance = onSelectInstance
        self.onPlayStop = onPlayStop
        self.onOpenSettings = onOpenSettings
        self.strings = strings
    }
}

/// Attaches the app-specific Touch Bar to the window that hosts the modified view.
public extension View {
    func touchBarSupport(_ configuration: TouchBarSupportConfiguration) -> some View {
        background(TouchBarInstaller(configuration: configuration))
    }
}

/// Centralized logger for the package.
enum TouchBarLog {
    static let log = Logger(subsystem: "com.swiftcraftlauncher.touchbar", category: "touchbar")
}
