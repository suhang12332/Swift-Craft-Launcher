//
//  GameLoader.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A Minecraft mod loader type.
enum GameLoader: String, CaseIterable, Identifiable, Codable, Sendable {
    case vanilla
    case fabric
    case forge
    case neoforge
    case quilt

    var id: String { rawValue }

    /// The display name shown in the UI.
    var displayName: String {
        switch self {
        case .vanilla: "vanilla"
        case .fabric: "fabric"
        case .forge: "forge"
        case .neoforge: "neoforge"
        case .quilt: "quilt"
        }
    }
}
