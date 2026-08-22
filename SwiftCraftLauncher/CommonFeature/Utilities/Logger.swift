//
//  Logger.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import os.log

/// Centralized module loggers for the application.
enum AppLog {
    /// Common infrastructure, networking, authentication, and shared utilities.
    static let common = os.Logger(subsystem: Bundle.main.identifier, category: "common")

    /// Game lifecycle: launch, Java management, mod scanning, version setup.
    static let game = os.Logger(subsystem: Bundle.main.identifier, category: "game")

    /// Player profiles, skins, and authentication accounts.
    static let player = os.Logger(subsystem: Bundle.main.identifier, category: "player")

    /// Remote resource browsing (Modrinth / CurseForge) and dependency resolution.
    static let resource = os.Logger(subsystem: Bundle.main.identifier, category: "resource")

    /// Mod-pack import, export, and installation workflows.
    static let modPack = os.Logger(subsystem: Bundle.main.identifier, category: "modpack")

    /// Main window, menus, and top-level UI coordination.
    static let main = os.Logger(subsystem: Bundle.main.identifier, category: "main")
}
