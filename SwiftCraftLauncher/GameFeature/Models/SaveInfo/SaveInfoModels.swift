//
//  SaveInfoModels.swift
//  GameFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A Minecraft world save.
struct WorldInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let path: URL
    let lastPlayed: Date?

    init(
        name: String,
        path: URL,
        lastPlayed: Date? = nil,
    ) {
        id = path.lastPathComponent
        self.name = name
        self.path = path
        self.lastPlayed = lastPlayed
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
