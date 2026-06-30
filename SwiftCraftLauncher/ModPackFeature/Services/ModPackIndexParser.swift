//
//  ModPackIndexParser.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Parses modpack index files by trying registered adapters.
enum ModPackIndexParser {
    /// Attempts to parse the modpack index at the extracted path.
    /// - Parameter extractedPath: The directory containing extracted modpack files.
    /// - Returns: A parsed index info, or nil if no adapter succeeded.
    static func parseIndex(extractedPath: URL) async -> ModrinthIndexInfo? {
        for adapter in adapters where await adapter.canParse(extractedPath: extractedPath) {
            if let info = await adapter.parseToModrinthIndexInfo(extractedPath: extractedPath) {
                return info
            }
        }
        return nil
    }

    private static let adapters: [any ModPackIndexAdapter] = [
        ModrinthIndexAdapter(),
        CurseForgeZipIndexAdapter(),
    ]
}
