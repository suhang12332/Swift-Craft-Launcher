//
//  EnvironmentVariablesParser.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Parses environment variables from a newline-separated string into a dictionary.
enum EnvironmentVariablesParser {
    /// Parses the environment variables string into a dictionary.
    /// - Parameter input: A string with one KEY=VALUE pair per line.
    /// - Returns: A dictionary of environment variable key-value pairs.
    static func parse(_ input: String) -> [String: String] {
        var env: [String: String] = [:]
        for line in input.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let equalIndex = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[..<equalIndex])
            let value = String(trimmed[trimmed.index(after: equalIndex)...])
            env[key] = value
        }
        return env
    }
}
