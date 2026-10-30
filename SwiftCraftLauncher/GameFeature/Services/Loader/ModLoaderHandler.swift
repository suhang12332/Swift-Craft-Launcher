//
//  ModLoaderHandler.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// The launch configuration produced when a mod loader is set up for an instance.
struct ModLoaderSetupResult {
    let loaderVersion: String
    let classpath: String
    let mainClass: String
    let gameArguments: [String]
    let jvmArguments: [String]
}

/// Defines the common interface for mod loader setup operations.
protocol ModLoaderHandler {
    static func setupWithSpecificVersionThrowing(
        for gameVersion: String,
        loaderVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping @Sendable (String, Int, Int) -> Void,
    ) async throws -> ModLoaderSetupResult

    static func setupWithSpecificVersion(
        for gameVersion: String,
        loaderVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping @Sendable (String, Int, Int) -> Void,
    ) async -> ModLoaderSetupResult?
}
