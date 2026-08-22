//
//  MemoryPressureChecker.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Represents the macOS memory pressure level reported by the kernel.
enum MemoryPressureLevel {
    case normal
    case warning
    case critical

    /// Whether the system is under elevated memory pressure.
    var isElevated: Bool { self != .normal }

    var localizedMessage: String {
        switch self {
        case .normal: ""
        case .warning: "game_launch.memory_pressure.warning_message".localized()
        case .critical: "game_launch.memory_pressure.critical_message".localized()
        }
    }
}

/// Queries the macOS kernel for the current memory pressure level.
enum MemoryPressureChecker {
    /// Returns the current memory pressure level via `kern.memorystatus_vm_pressure_level`.
    static func check() -> MemoryPressureLevel {
        var value: UInt32 = 0
        var size = MemoryLayout<UInt32>.size
        let result = sysctlbyname("kern.memorystatus_vm_pressure_level", &value, &size, nil, 0)
        guard result == 0 else {
            AppLog.game.warning("Failed to query memory pressure level, sysctl returned \(result)")
            return .normal
        }
        switch value {
        case 2: return .warning
        case 4: return .critical
        default: return .normal
        }
    }
}

/// Reports the Java state that would prevent a reliable launch.
struct GameIntegrityReport {
    let errors: [GlobalError]

    var isValid: Bool { errors.isEmpty }
}

/// Performs the minimum pre-launch integrity check and repair.
enum GameIntegrityChecker {
    static func check(game: GameVersionInfo) async -> GameIntegrityReport {
        var errors: [GlobalError] = []
        let javaManager = DIContainer.shared.system.javaManager

        if game.javaPath.isEmpty || !FileManager.default.isExecutableFile(atPath: game.javaPath) {
            errors.append(.gameLaunch(i18nKey: "game_launch.integrity.java_missing"))
        } else if !javaManager.canJavaRun(at: game.javaPath) {
            errors.append(.gameLaunch(i18nKey: "game_launch.integrity.java_unusable"))
        }

        return GameIntegrityReport(errors: errors)
    }

    static func repair(game: GameVersionInfo) async throws -> GameVersionInfo {
        let manifest = try await ModrinthService.fetchVersionInfo(from: game.gameVersion)
        let javaPath = await DIContainer.shared.system.javaManager.ensureJavaExists(
            version: manifest.javaVersion.component,
        )
        guard !javaPath.isEmpty else {
            throw GlobalError.configuration(
                i18nKey: "error.configuration.java_path_not_set",
                level: .popup,
                message: "Failed to repair Java runtime for version \(manifest.javaVersion.component)",
            )
        }

        try await MinecraftFileManager().downloadVersionFilesThrowing(
            manifest: manifest,
            gameName: game.gameName,
        )

        var repairedGame = game
        repairedGame.javaPath = javaPath
        repairedGame.javaVersion = manifest.javaVersion.majorVersion
        return repairedGame
    }
}
