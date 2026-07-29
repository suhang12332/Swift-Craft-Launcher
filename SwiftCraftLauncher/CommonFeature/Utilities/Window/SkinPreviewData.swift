//
//  SkinPreviewData.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SkinRenderKit

/// Data model for skin preview rendering.
struct SkinPreviewData {
    let skinImage: NSImage?
    let skinPath: String?
    let capeImage: NSImage?
    let playerModel: PlayerModel
}
