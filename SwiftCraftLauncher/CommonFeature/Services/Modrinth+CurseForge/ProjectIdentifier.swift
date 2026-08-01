//
//  ProjectIdentifier.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Encapsulates project ID routing between Modrinth and CurseForge.
///
/// CurseForge project IDs are prefixed with `"cf-"` throughout the app.
/// This type centralizes the detection, normalization, and parsing of that convention.
struct ProjectIdentifier: Equatable, Hashable {
    let raw: String

    /// Whether this identifier refers to a CurseForge project.
    var isCurseForge: Bool { raw.hasPrefix("cf-") }

    /// Whether this identifier refers to a Modrinth project.
    var isModrinth: Bool { !isCurseForge }

    /// The normalized form: always `"cf-<numericId>"` for CurseForge, unchanged for Modrinth.
    var normalized: String {
        if isCurseForge {
            return raw
        }
        if Int(raw) != nil {
            return "cf-\(raw)"
        }
        return raw
    }

    /// The numeric CurseForge mod ID, or `nil` if this is a Modrinth identifier.
    var curseForgeModId: Int? {
        guard isCurseForge else { return nil }
        let clean = raw.replacingOccurrences(of: "cf-", with: "")
        return Int(clean)
    }

    /// Parses the identifier into its CurseForge numeric ID and normalized string.
    /// Accepts both `"cf-12345"` and plain `"12345"` forms.
    func parseCurseForgeId() throws -> (modId: Int, normalized: String) {
        let clean = raw.replacingOccurrences(of: "cf-", with: "")
        guard let modId = Int(clean) else {
            throw GlobalError.validation(
                i18nKey: "error.validation.invalid_project_id",
                level: .notification,
                message: "CurseForge ID '\(raw)' is not a valid integer after stripping 'cf-' prefix",
            )
        }
        let normalized = isCurseForge ? raw : "cf-\(clean)"
        return (modId, normalized)
    }

    /// Creates a `ProjectIdentifier` from a raw string.
    init(_ raw: String) {
        self.raw = raw
    }
}

extension String {
    var asProjectId: ProjectIdentifier { ProjectIdentifier(self) }
}
