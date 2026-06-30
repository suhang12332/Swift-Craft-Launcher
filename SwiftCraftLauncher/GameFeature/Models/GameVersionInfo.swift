//
//  GameVersionInfo.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Represents a game version's metadata and launch configuration.
struct GameVersionInfo: Codable, Identifiable, Hashable {
    /// The unique identifier for this game version.
    let id: String

    /// The display name of the game.
    let gameName: String

    /// The path or URL of the game icon.
    var gameIcon: String

    /// The game version string.
    let gameVersion: String

    /// The mod version string.
    var modVersion: String

    /// JVM arguments specific to the mod loader.
    var modJvm: [String] = []

    var modClassPath: String

    /// The asset index version identifier.
    var assetIndex: String

    /// The mod loader type (e.g., Forge, Fabric).
    let modLoader: String

    /// The date and time the version was last played.
    var lastPlayed: Date

    /// The file path to the Java runtime.
    var javaPath: String

    /// Custom JVM startup arguments.
    var jvmArguments: String

    /// The launch command array.
    var launchCommand: [String]

    /// The minimum memory allocation in megabytes.
    var xms: Int

    /// The maximum memory allocation in megabytes.
    var xmx: Int

    var javaVersion: Int

    /// The fully qualified main class name.
    var mainClass: String

    /// Additional game arguments passed at launch.
    var gameArguments: [String] = []

    /// Environment variables set for the game process.
    var environmentVariables: String

    /// Creates a game version info with the specified parameters.
    /// - Parameters:
    ///   - id: The unique identifier. Defaults to a new UUID.
    ///   - gameName: The display name of the game.
    ///   - gameIcon: The path or URL of the game icon.
    ///   - gameVersion: The game version string.
    ///   - modVersion: The mod version string.
    ///   - modJvm: JVM arguments for the mod loader.
    ///   - modClassPath: The mod classpath string.
    ///   - assetIndex: The asset index version identifier.
    ///   - modLoader: The mod loader type.
    ///   - lastPlayed: The last played date. Defaults to the current date.
    ///   - javaPath: The file path to the Java runtime.
    ///   - jvmArguments: Custom JVM startup arguments.
    ///   - launchCommand: The launch command array.
    ///   - xms: The minimum memory allocation in megabytes.
    ///   - xmx: The maximum memory allocation in megabytes.
    ///   - javaVersion: The Java major version number.
    ///   - mainClass: The fully qualified main class name.
    ///   - gameArguments: Additional game arguments.
    ///   - environmentVariables: Environment variables for the game process.
    init(
        id: UUID = UUID(),
        gameName: String,
        gameIcon: String,
        gameVersion: String,
        modVersion: String = "",
        modJvm: [String] = [],
        modClassPath: String = "",
        assetIndex: String,
        modLoader: String,
        lastPlayed: Date = Date(),
        javaPath: String = "",
        jvmArguments: String = "",
        launchCommand: [String] = [],
        xms: Int = 0,
        xmx: Int = 0,
        javaVersion: Int = 8,
        mainClass: String = "",
        gameArguments: [String] = [],
        environmentVariables: String = ""
    ) {
        self.id = id.uuidString
        self.gameName = gameName
        self.gameIcon = gameIcon
        self.gameVersion = gameVersion
        self.modVersion = modVersion
        self.modJvm = modJvm
        self.modClassPath = modClassPath
        self.assetIndex = assetIndex
        self.modLoader = modLoader
        self.lastPlayed = lastPlayed
        self.javaPath = javaPath
        self.jvmArguments = jvmArguments
        self.launchCommand = launchCommand
        self.xms = xms
        self.xmx = xmx
        self.mainClass = mainClass
        self.gameArguments = gameArguments
        self.javaVersion = javaVersion
        self.environmentVariables = environmentVariables
    }
}
