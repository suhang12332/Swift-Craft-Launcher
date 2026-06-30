//
//  GameIconProcessor.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import CoreGraphics
import Foundation
import ImageIO

/// Provides image optimization utilities for game icons.
enum GameIconProcessor {
    static let maxIconPixelSize = 128

    /// Downscales and converts image data to PNG format.
    /// - Parameters:
    ///   - data: The raw image data to optimize.
    ///   - maxPixelSize: The maximum width or height in pixels. Defaults to ``maxIconPixelSize``.
    /// - Returns: Optimized PNG data, or the original data if processing fails.
    static func optimize(data: Data, maxPixelSize: Int = maxIconPixelSize) -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return data
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return data
        }

        let bitmap = NSBitmapImageRep(cgImage: downsampledImage)
        return bitmap.representation(using: .png, properties: [:]) ?? data
    }
}
