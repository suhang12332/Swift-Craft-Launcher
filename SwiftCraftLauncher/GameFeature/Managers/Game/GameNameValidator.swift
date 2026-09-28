//
//  GameNameValidator.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Validates game names to prevent duplicates during creation.
@MainActor
@Observable
class GameNameValidator {
    var gameName: String = ""
    var isGameNameDuplicate: Bool = false

    /// Characters that must never appear in a profile directory name.
    ///
    /// Path separators and control characters are rejected wherever they occur; the `..`
    /// sequence and the `.` alias are handled separately by `isValidName(_:)`.
    private static let invalidNameCharacters: CharacterSet = {
        var characters = CharacterSet(charactersIn: "/\\:")
        characters.formUnion(.controlCharacters)
        return characters
    }()

    init() { }

    /// Sets a default game name only when the current name is empty.
    /// - Parameter name: The default name to set.
    func setDefaultName(_ name: String) {
        if gameName.isEmpty {
            gameName = name
        }
    }

    func reset() {
        gameName = ""
        isGameNameDuplicate = false
    }

    /// A Boolean value indicating whether the trimmed name is safe to use as a directory name.
    ///
    /// The name becomes a single path component under the profile root, so a name such as
    /// `a/../Other` would otherwise create or delete files outside of that root.
    var isNameValid: Bool {
        Self.isValidName(gameName)
    }

    /// Returns whether a raw name can be used as a profile directory name.
    ///
    /// The name is trimmed first because the profile directory is created from the trimmed
    /// value. The check applies to the whole name, so path separators, the `..` sequence and
    /// control characters are rejected at the start, the middle and the end alike, which keeps
    /// the resulting directory inside the profile root. A leading or trailing dot is rejected
    /// as well: it marks hidden files, and a trailing dot is dropped silently by some file
    /// system operations, so both would produce a directory other than the requested one.
    static func isValidName(_ rawName: String) -> Bool {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

        if name.isEmpty || name.hasPrefix(".") || name.hasSuffix(".") || name.contains("..") {
            return false
        }

        return name.rangeOfCharacter(from: invalidNameCharacters) == nil
    }

    /// A Boolean value indicating whether the form input is valid.
    ///
    /// The profile directory is created from the trimmed name, so this must trim as well.
    /// Testing the raw input would accept a name made of whitespace only, which then installs
    /// into a directory that duplicate detection never inspected. Path-like input is rejected
    /// by `isValidName(_:)` for the same reason: the trimmed name is used as a path component.
    var isFormValid: Bool {
        isNameValid && !isGameNameDuplicate
    }
}
