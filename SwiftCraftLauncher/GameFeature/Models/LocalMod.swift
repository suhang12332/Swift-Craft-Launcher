//
//  LocalMod.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Lightweight record for a mod file found in a game's `mods` directory.
struct LocalMod {
    static let requiredDependencyType = "required"

    let projectId: String
    let title: String
    let iconUrl: String?
    let dependencyProjectIds: [String]
    let fileName: String
    let isEnabled: Bool

    init(
        project: ModrinthProjectDetail,
        installedVersion: ModrinthProjectDetailVersion?,
        fileName: String,
        isEnabled: Bool,
    ) {
        projectId = project.id
        title = project.title
        iconUrl = project.iconUrl
        self.fileName = fileName
        self.isEnabled = isEnabled

        var dependencies: [String] = []
        var seenProjectIds: Set<String> = []
        for dependency in installedVersion?.dependencies ?? []
            where dependency.dependencyType == Self.requiredDependencyType {
            guard let dependencyId = dependency.projectId,
                  dependencyId != project.id,
                  seenProjectIds.insert(dependencyId).inserted
            else {
                continue
            }
            dependencies.append(dependencyId)
        }
        dependencyProjectIds = dependencies
    }
}
