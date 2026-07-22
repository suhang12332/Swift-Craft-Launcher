//
//  VersionFilter.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Shared logic for filtering Modrinth-format versions by game version and loader.
enum VersionFilter {
    /// Filters a list of Modrinth-format versions by the selected game versions and loaders.
    ///
    /// - Parameters:
    ///   - versions: The versions to filter.
    ///   - selectedVersions: The selected game versions (empty = accept all).
    ///   - selectedLoaders: The selected mod loader types (empty = accept all).
    ///   - type: The resource type (mod, shader, resourcepack, datapack).
    /// - Returns: The filtered versions.
    static func filter(
        _ versions: [ModrinthProjectDetailVersion],
        selectedVersions: [String],
        selectedLoaders: [String],
        type: String,
    ) -> [ModrinthProjectDetailVersion] {
        var loaders = selectedLoaders
        let lowercasedType = type.lowercased()

        if lowercasedType == ResourceType.datapack.rawValue {
            loaders = [ResourceType.datapack.rawValue]
        } else if lowercasedType == ResourceType.resourcepack.rawValue {
            loaders = ["minecraft"]
        }

        return versions.filter { version in
            let versionMatch = selectedVersions.isEmpty
                || !Set(version.gameVersions).isDisjoint(with: selectedVersions)

            let loaderMatch: Bool
            if lowercasedType == ResourceType.shader.rawValue || lowercasedType == ResourceType.resourcepack.rawValue {
                loaderMatch = true
            } else {
                loaderMatch = loaders.isEmpty || !Set(version.loaders).isDisjoint(with: loaders)
            }

            return versionMatch && loaderMatch
        }
    }

    /// Determines whether the given resource type should skip loader filtering.
    static func shouldSkipLoaderFilter(for type: String) -> Bool {
        let lowercased = type.lowercased()
        return lowercased == ResourceType.shader.rawValue
            || lowercased == ResourceType.resourcepack.rawValue
            || lowercased == ResourceType.datapack.rawValue
    }
}
