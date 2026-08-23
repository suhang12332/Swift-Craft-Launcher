//
//  Logger.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import os.log

/// Writes already-reviewed application log messages with visible interpolation values.
struct VisibleLogger: Sendable {
    private let logger: Logger

    init(subsystem: String, category: String) {
        logger = Logger(subsystem: subsystem, category: category)
    }

    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}

/// Centralized module loggers for the application.
enum AppLog {
    /// Common infrastructure, networking, authentication, and shared utilities.
    static let common = VisibleLogger(subsystem: Bundle.main.identifier, category: "common")

    /// Game lifecycle: launch, Java management, mod scanning, version setup.
    static let game = VisibleLogger(subsystem: Bundle.main.identifier, category: "game")

    /// Player profiles, skins, and authentication accounts.
    static let player = VisibleLogger(subsystem: Bundle.main.identifier, category: "player")

    /// Remote resource browsing (Modrinth / CurseForge) and dependency resolution.
    static let resource = VisibleLogger(subsystem: Bundle.main.identifier, category: "resource")

    /// Mod-pack import, export, and installation workflows.
    static let modPack = VisibleLogger(subsystem: Bundle.main.identifier, category: "modpack")

    /// Main window, menus, and top-level UI coordination.
    static let main = VisibleLogger(subsystem: Bundle.main.identifier, category: "main")
}
