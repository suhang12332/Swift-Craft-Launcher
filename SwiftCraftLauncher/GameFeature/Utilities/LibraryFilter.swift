//
//  LibraryFilter.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Unified library filtering utilities for download and classpath construction.
enum LibraryFilter {

    /// Determines whether a library is allowed based on platform rules.
    /// - Parameters:
    ///   - library: The library to check.
    ///   - minecraftVersion: The Minecraft version string, if available.
    /// - Returns: `true` if the library is allowed; `false` otherwise.
    static func isLibraryAllowed(_ library: Library, minecraftVersion: String? = nil) -> Bool {
        guard let rules = library.rules, !rules.isEmpty else { return true }
        return MacRuleEvaluator.isAllowed(rules, minecraftVersion: minecraftVersion)
    }

    /// Determines whether a library should be downloaded.
    /// - Parameters:
    ///   - library: The library to check.
    ///   - minecraftVersion: The Minecraft version string, if available.
    /// - Returns: `true` if the library should be downloaded; `false` otherwise.
    static func shouldDownloadLibrary(_ library: Library, minecraftVersion: String? = nil) -> Bool {
        guard library.downloadable else { return false }
        return isLibraryAllowed(library, minecraftVersion: minecraftVersion)
    }

    /// Determines whether a library should be included in the classpath.
    /// - Parameters:
    ///   - library: The library to check.
    ///   - minecraftVersion: The Minecraft version string, if available.
    /// - Returns: `true` if the library should be included in the classpath; `false` otherwise.
    static func shouldIncludeInClasspath(_ library: Library, minecraftVersion: String? = nil) -> Bool {
        guard library.downloadable == true && library.includeInClasspath == true else {
            return false
        }
        return isLibraryAllowed(library, minecraftVersion: minecraftVersion)
    }
}
