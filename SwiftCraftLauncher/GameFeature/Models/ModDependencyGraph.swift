//
//  ModDependencyGraph.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Flattened dependency graph used by the drawing layer.
///
/// Each project appears exactly once. Edges point from a mod to its required
/// dependency.
struct ModDependencyGraph {
    struct Node: Identifiable, Sendable {
        let projectId: String
        let title: String
        let iconUrl: String?
        let fileName: String?
        let isEnabled: Bool
        let isCycle: Bool

        var id: String { projectId }
        var isInstalled: Bool { fileName != nil }
    }

    struct Edge: Sendable {
        let from: String
        let to: String
    }

    let nodes: [Node]
    let edges: [Edge]
}
