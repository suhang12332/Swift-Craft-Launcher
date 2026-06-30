//
//  SaveInfoModels.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A Minecraft world save.
struct WorldInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let path: URL
    let lastPlayed: Date?
    let gameMode: String?
    let difficulty: String?

    /// Whether the world is in hardcore mode.
    let hardcore: Bool

    /// Whether cheats and commands are enabled.
    let cheats: Bool

    let version: String?
    let seed: Int64?

    init(
        name: String,
        path: URL,
        lastPlayed: Date? = nil,
        gameMode: String? = nil,
        difficulty: String? = nil,
        hardcore: Bool = false,
        cheats: Bool = false,
        version: String? = nil,
        seed: Int64? = nil,
    ) {
        id = path.lastPathComponent
        self.name = name
        self.path = path
        self.lastPlayed = lastPlayed
        self.gameMode = gameMode
        self.difficulty = difficulty
        self.hardcore = hardcore
        self.cheats = cheats
        self.version = version
        self.seed = seed
    }
}

/// A screenshot taken in-game.
struct ScreenshotInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let path: URL
    let createdDate: Date?
    let fileSize: Int64

    init(name: String, path: URL, createdDate: Date? = nil, fileSize: Int64 = 0) {
        id = path.lastPathComponent
        self.name = name
        self.path = path
        self.createdDate = createdDate
        self.fileSize = fileSize
    }
}

/// A game log file entry.
struct LogInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let path: URL
    let createdDate: Date?
    let fileSize: Int64
    let isCrashLog: Bool

    init(name: String, path: URL, createdDate: Date? = nil, fileSize: Int64 = 0, isCrashLog: Bool = false) {
        id = path.lastPathComponent
        self.name = name
        self.path = path
        self.createdDate = createdDate
        self.fileSize = fileSize
        self.isCrashLog = isCrashLog
    }
}

/// Detailed metadata for a Minecraft world.
struct WorldDetailMetadata {
    let levelName: String
    let folderName: String
    let path: URL
    let lastPlayed: Date?
    let gameMode: String
    let difficulty: String
    let hardcore: Bool
    let cheats: Bool
    let versionName: String?
    let versionId: Int?
    let dataVersion: Int?
    let seed: Int64?
    let spawn: String?
    let time: Int64?
    let dayTime: Int64?
    let weather: String?
    let worldBorder: String?
    let gameRules: [String]?
}
