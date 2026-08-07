//
//  GameLoader.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A Minecraft mod loader type.
enum GameLoader: String, CaseIterable, Identifiable, Codable {
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

    /// The capitalized name for user-facing messages (logs, errors).
    var labelName: String {
        switch self {
        case .vanilla: "Vanilla"
        case .fabric: "Fabric"
        case .forge: "Forge"
        case .neoforge: "NeoForge"
        case .quilt: "Quilt"
        }
    }

    /// The Modrinth API loader identifier.
    var modrinthLoaderId: String {
        switch self {
        case .neoforge: "neo"
        default: displayName
        }
    }
}
