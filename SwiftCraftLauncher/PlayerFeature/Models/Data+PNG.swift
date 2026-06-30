//
//  Data+PNG.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Whether the data represents a PNG image.
extension Data {
    /// A Boolean value indicating whether the data represents a PNG image.
    var isPNG: Bool {
        starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }
}
