//
//  DIContainer.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import MinecraftFriendsKit
import Observation
import SwiftUI

/// Centralized dependency container that owns all shared service instances.
@Observable
final class DIContainer {
    static let shared = DIContainer()

    // UI

    var ui = UIContainer()

    // Core

    var core = CoreContainer()

    // System

    var system = SystemContainer()

    init() { }
}
