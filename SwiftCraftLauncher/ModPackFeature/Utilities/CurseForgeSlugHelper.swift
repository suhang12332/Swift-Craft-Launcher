//
//  CurseForgeSlugHelper.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Utility for validating and converting text to CurseForge-compatible slugs.
///
/// CurseForge slug rules: `^[\w!@$()`.+,"\-']{3,64}$`
enum CurseForgeSlugHelper {
    private static let allowedCharacters: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "_!@$()`.+,\"-'")
        return set
    }()

    /// Converts text to a CurseForge-compatible slug.
    /// - Parameter text: The input text to convert.
    /// - Returns: A valid slug string, or an empty string if the result is too short.
    static func toSlug(_ text: String) -> String {
        guard !text.isEmpty else { return "" }

        let lowercased = text.lowercased()
        var result = ""
        var lastWasDash = false

        for ch in lowercased {
            if ch.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) {
                result.append(ch)
                lastWasDash = false
            } else {
                if !lastWasDash {
                    result.append("-")
                    lastWasDash = true
                }
            }
        }

        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        if trimmed.count < 3 {
            return ""
        }
        if trimmed.count > 64 {
            return String(trimmed.prefix(64))
        }

        return trimmed
    }

    /// Validates whether a string is a valid CurseForge slug.
    /// - Parameter slug: The slug to validate.
    /// - Returns: `true` if the slug meets length and character requirements.
    static func isValid(_ slug: String) -> Bool {
        guard slug.count >= 3, slug.count <= 64 else {
            return false
        }

        for scalar in slug.unicodeScalars where !allowedCharacters.contains(scalar) {
            return false
        }

        return true
    }
}
