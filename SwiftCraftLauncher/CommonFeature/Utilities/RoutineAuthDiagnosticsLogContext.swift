//
//  RoutineAuthDiagnosticsLogContext.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Controls suppression of routine authentication debug logs to reduce noise.
enum RoutineAuthDiagnosticsLogContext {
    @TaskLocal static var suppressRoutineDebugLogs = false

    static var shouldSuppressRoutineDebugLogs: Bool {
        suppressRoutineDebugLogs
    }
}
