//
//  FailedModPackResource.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Represents a resource that failed to download during modpack installation.
struct FailedModPackResource: Identifiable {
    let id = UUID()
    let projectDetail: ModrinthProjectDetail
    let resourceType: String
    let gameInfo: GameVersionInfo
}
