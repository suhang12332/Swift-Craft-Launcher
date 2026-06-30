//
//  CurseForgeZipIndexAdapter.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Parses CurseForge mod pack archives into a normalized index representation.
struct CurseForgeZipIndexAdapter: ModPackIndexAdapter {
    let id: String = "curseforge"

    /// Determines whether the extracted directory contains a CurseForge manifest.
    ///
    /// - Parameter extractedPath: The root directory of the extracted archive.
    /// - Returns: `true` if a `manifest.json` file exists at the root.
    func canParse(extractedPath: URL) async -> Bool {
        let manifestPath = extractedPath.appendingPathComponent("manifest.json")
        return await Task.detached(priority: .userInitiated) {
            FileManager.default.fileExists(atPath: manifestPath.path)
        }.value
    }

    /// Parses the CurseForge manifest into a normalized mod pack index.
    ///
    /// - Parameter extractedPath: The root directory of the extracted archive.
    /// - Returns: A normalized index info structure, or `nil` if parsing fails.
    func parseToModrinthIndexInfo(extractedPath: URL) async -> ModrinthIndexInfo? {
        await CurseForgeManifestParser.parseManifest(extractedPath: extractedPath)
    }
}
