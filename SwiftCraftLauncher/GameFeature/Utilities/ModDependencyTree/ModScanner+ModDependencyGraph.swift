//
//  ModScanner+ModDependencyGraph.swift
//  GameFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension ModScanner {
    /// Retrieves the project detail and returns the computed hash for callers
    /// that need to resolve the installed version as well.
    func getModrinthProjectDetailWithHash(
        for fileURL: URL,
    ) async throws -> (project: ModrinthProjectDetail, hash: String)? {
        let hash = try await requiredSHA1Hash(for: fileURL)
        guard let project = try await getModrinthProjectDetail(for: fileURL, hash: hash) else {
            return nil
        }
        return (project, hash)
    }
}
