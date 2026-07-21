//
//  ModPackIndexAdapter.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

protocol ModPackIndexAdapter {
    /// The unique identifier for this adapter.
    var id: String { get }

    /// Determines whether the extracted directory can be parsed by this adapter.
    func canParse(extractedPath: URL) async -> Bool

    /// Parses the extracted directory and returns a unified Modrinth index.
    func parseToModrinthIndexInfo(extractedPath: URL) async -> ModrinthIndexInfo?
}
