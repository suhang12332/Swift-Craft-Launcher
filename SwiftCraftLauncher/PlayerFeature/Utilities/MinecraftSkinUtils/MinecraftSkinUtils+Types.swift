//
//  MinecraftSkinUtils+Types.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import CoreImage
import Foundation
import SwiftUI

/// The source type of a skin image.
enum SkinType {
    /// Loaded from a remote URL.
    case url
    /// Loaded from the app's asset catalog.
    case asset
    /// Loaded from a local file path.
    case local
}

/// A cached rendering of a Minecraft skin head and its overlay layer.
final class RenderedImageCache: NSObject {
    /// The rendered head image.
    let headImage: CGImage
    /// The overlay layer image (hat or second layer).
    let layerImage: CGImage
    /// A Boolean value indicating whether the overlay layer has visible content.
    let hasLayerContent: Bool
    /// The approximate memory cost of this cache entry.
    let cost: Int

    init(headImage: CGImage, layerImage: CGImage, hasLayerContent: Bool) {
        self.headImage = headImage
        self.layerImage = layerImage
        self.hasLayerContent = hasLayerContent
        let headCost = Int(headImage.width * headImage.height * 4)
        let layerCost = Int(layerImage.width * layerImage.height * 4)
        cost = headCost + layerCost + 2 * 1024
        super.init()
    }
}

/// Constants used for Minecraft skin rendering and caching.
enum MinecraftSkinConstants {
    static let padding: CGFloat = 6
    static let networkTimeout: TimeInterval = 10.0
    static let maxCacheSize = 100
    static let maxCacheMemory = 2 * 1024 * 1024

    static let headStartX: CGFloat = 8
    static let headStartY: CGFloat = 8
    static let headWidth: CGFloat = 8
    static let headHeight: CGFloat = 8

    static let layerStartX: CGFloat = 40
    static let layerStartY: CGFloat = 8
    static let layerWidth: CGFloat = 8
    static let layerHeight: CGFloat = 8
}
