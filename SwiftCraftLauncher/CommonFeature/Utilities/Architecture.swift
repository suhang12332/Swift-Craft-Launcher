//
//  Architecture.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Identifies the CPU architecture of the running process and provides architecture-specific strings.
enum Architecture {
    case arm64
    case x86_64

    /// The current process architecture.
    static let current: Architecture = {
        #if arch(arm64)
        return .arm64
        #else
        return .x86_64
        #endif
    }()

    /// The architecture identifier used by Java.
    var javaArch: String {
        switch self {
        case .arm64: return "aarch64"
        case .x86_64: return "x86_64"
        }
    }

    /// The architecture identifier used by Sparkle and other general-purpose APIs.
    var sparkleArch: String {
        switch self {
        case .arm64: return "arm64"
        case .x86_64: return "x86_64"
        }
    }

    /// The platform identifier for the Java Runtime API.
    var macPlatformId: String {
        switch self {
        case .arm64: return "mac-os-arm64"
        case .x86_64: return "mac-os"
        }
    }

    /// Returns the macOS library identifiers for the current architecture, ordered by priority.
    /// - Parameter isLowVersion: Whether the target Minecraft version is below 1.19.
    func macOSIdentifiers(isLowVersion: Bool) -> [String] {
        switch self {
        case .arm64:
            if isLowVersion {
                return ["osx-arm64", "macos-arm64"]
            } else {
                return ["osx-arm64", "macos-arm64", "osx", "macos"]
            }
        case .x86_64:
            return ["osx", "macos"]
        }
    }
}
