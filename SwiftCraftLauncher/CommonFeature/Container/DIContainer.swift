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
final class DIContainer: @unchecked Sendable {
    static let shared = DIContainer()

    // UI

    let ui = UIContainer()

    // Core

    let core = CoreContainer()

    // System

    let system = SystemContainer()

    init() { }
}
