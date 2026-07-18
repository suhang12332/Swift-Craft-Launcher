//
//  JavaDetailsFormatting.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Formats Java runtime details into a human-readable description string.
enum JavaDetailsFormatting {
    /// Returns a two-line string combining the executable path and version output.
    /// - Parameters:
    ///   - javaExecutablePath: The file path to the Java executable.
    ///   - versionOutput: The raw version output from the Java runtime.
    /// - Returns: A formatted string with the path on the first line and version on the second.
    static func description(javaExecutablePath: String, versionOutput: String) -> String {
        let versionPart = versionOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathPart = javaExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        return [pathPart, versionPart]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
