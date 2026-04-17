import Foundation
import AppKit
import CoreGraphics
import ImageIO

enum GameIconProcessor {
    static let maxIconPixelSize = 128

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
