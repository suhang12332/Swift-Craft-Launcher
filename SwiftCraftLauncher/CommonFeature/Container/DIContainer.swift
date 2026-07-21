//
//  DIContainer.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import MinecraftFriendsKit
import SwiftUI

/// Centralized dependency container that owns all shared service instances.
/// AppServices delegates to this container internally.
final class DIContainer: ObservableObject {
    static let shared = DIContainer()

    // UI

    var ui = UIContainer()

    // Core

    var core = CoreContainer()

    // System

    var system = SystemContainer()

    init() { }
}
