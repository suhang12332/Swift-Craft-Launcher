//
//  MacRuleEvaluator.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Represents macOS platform identifiers for library compatibility checks.
enum MacOS: String {
    case osx
    case osxArm64 = "osx-arm64"
    case osxX86_64 = "osx-x86_64"

    /// Creates a `MacOS` value from a Java architecture string.
    /// - Parameter javaArch: The Java architecture identifier (e.g., "aarch64", "x86_64").
    /// - Returns: The corresponding `MacOS` value.
    static func fromJavaArch(_ javaArch: String) -> Self {
        let arch = javaArch.lowercased()
        if arch.contains("aarch64") {
            return .osxArm64
        } else if arch.contains("x86_64") || arch.contains("amd64") {
            return .osxX86_64
        } else {
            return .osx
        }
    }
}

/// Represents a rule action for library compatibility.
enum RuleAction: String {
    case allow
    case disallow
}

/// A simplified rule structure for macOS compatibility evaluation.
struct MacRule {
    let action: RuleAction
    let os: MacOS?
}

/// Evaluates Minecraft library rules against the current platform.
enum MacRuleEvaluator {
    /// Returns the Java architecture string for the current platform.
    /// - Returns: A Java architecture identifier (e.g., "aarch64", "x86_64").
    static func getCurrentJavaArch() -> String {
        #if os(macOS)
        return Architecture.current.javaArch
        #else
        return "x86_64"
        #endif
    }

    /// Determines whether the given Minecraft version uses strict architecture matching.
    /// - Parameter version: The Minecraft version string.
    /// - Returns: `true` if the version is below 1.19.
    static func isLowVersion(_ version: String) -> Bool {
        let versionComponents = version.split(separator: ".").compactMap { Int($0) }
        guard versionComponents.count >= 2 else { return false }

        let major = versionComponents[0]
        let minor = versionComponents[1]

        // Versions below 1.19 use strict architecture matching.
        return major < 1 || (major == 1 && minor < 19)
    }

    /// Returns a list of supported platform identifiers for the current system, ordered by priority.
    /// - Parameter minecraftVersion: The Minecraft version string, if available.
    /// - Returns: An array of platform identifier strings.
    static func getSupportedMacOSIdentifiers(minecraftVersion: String? = nil) -> [String] {
        #if os(macOS)
        let isLowVersion = minecraftVersion.map { Self.isLowVersion($0) } ?? false

        return Architecture.current.macOSIdentifiers(isLowVersion: isLowVersion)
        #elseif os(Linux)
        return ["linux"]
        #elseif os(Windows)
        return ["windows"]
        #else
        return []
        #endif
    }

    /// Checks whether a platform identifier is supported on the current system.
    /// - Parameters:
    ///   - identifier: The platform identifier to check.
    ///   - minecraftVersion: The Minecraft version string, if available.
    /// - Returns: `true` if the identifier is supported; `false` otherwise.
    static func isPlatformIdentifierSupported(_ identifier: String, minecraftVersion: String? = nil) -> Bool {
        getSupportedMacOSIdentifiers(minecraftVersion: minecraftVersion).contains(identifier)
    }

    /// Converts Minecraft library rules into simplified `MacRule` structures.
    /// - Parameter rules: The original Minecraft rules.
    /// - Returns: An array of `MacRule` values, excluding non-macOS rules.
    static func convertFromMinecraftRules(_ rules: [Rule]) -> [MacRule] {
        rules.compactMap { rule in
            guard let action = RuleAction(rawValue: rule.action) else { return nil }

            let macOS: MacOS?
            if let osName = rule.os?.name, let validMacOS = MacOS(rawValue: osName) {
                macOS = validMacOS
            } else if rule.os?.name != nil {
                return nil // Non-macOS rule.
            } else {
                macOS = nil // No OS restriction.
            }

            return MacRule(action: action, os: macOS)
        }
    }

    /// Determines whether the given library rules allow the library on the current platform.
    /// - Parameters:
    ///   - rules: The library rules to evaluate.
    ///   - minecraftVersion: The Minecraft version string, if available.
    /// - Returns: `true` if the library is allowed; `false` otherwise.
    static func isAllowed(_ rules: [Rule], minecraftVersion: String? = nil) -> Bool {
        guard !rules.isEmpty else { return true }

        let macRules = convertFromMinecraftRules(rules)

        // If original rules are non-empty but conversion produced nothing, all rules are non-macOS.
        if macRules.isEmpty {
            return false
        }

        let supportedIdentifiers = getSupportedMacOSIdentifiers(minecraftVersion: minecraftVersion)

        // Find applicable rules based on supported identifiers, ordered by priority.
        var applicableRules: [MacRule] = []

        for identifier in supportedIdentifiers {
            let macOS = MacOS(rawValue: identifier)
            let matchingRules = macRules.filter { rule in
                rule.os == nil || rule.os == macOS
            }
            if !matchingRules.isEmpty {
                applicableRules = matchingRules
                break
            }
        }

        // Fall back to rules with no OS restriction if none matched.
        if applicableRules.isEmpty {
            applicableRules = macRules.filter { $0.os == nil }
        }

        guard !applicableRules.isEmpty else { return false }

        if applicableRules.contains(where: { $0.action == .disallow }) {
            return false
        }

        return applicableRules.contains { $0.action == .allow }
    }
}
