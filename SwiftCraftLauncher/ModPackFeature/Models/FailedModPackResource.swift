//
//  FailedModPackResource.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Represents a resource that failed to download during modpack installation.
struct FailedModPackResource: Identifiable, Sendable {
    /// A stable identity derived from the project, resource type, and game version,
    /// so UI updates remain predictable across window re-presentations.
    var id: String {
        "\(projectDetail.id)-\(resourceType)-\(gameInfo.gameVersion)"
    }

    let projectDetail: ModrinthProjectDetail
    let resourceType: String
    let gameInfo: GameVersionInfo
}
