//
//  ProgressUtil.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Utility functions for progress calculations.
enum ProgressUtil {
    /// Calculates a clamped progress ratio between 0.0 and 1.0.
    static func calculateProgress(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0.0 }
        return max(0.0, min(1.0, Double(completed) / Double(total)))
    }
}
