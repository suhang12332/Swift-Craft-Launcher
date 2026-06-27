import SwiftUI
import CoreImage
import Foundation

extension MinecraftSkinUtils {

    static let imageCache: NSCache<NSString, RenderedImageCache> = {
        let cache = NSCache<NSString, RenderedImageCache>()
        cache.countLimit = MinecraftSkinConstants.maxCacheSize
        cache.totalCostLimit = MinecraftSkinConstants.maxCacheMemory
        cache.name = "MinecraftSkinCache"
        return cache
    }()

    static let ciContext: CIContext = {
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: true,
            .cacheIntermediates: false,
            .name: "MinecraftSkinProcessor",
        ]
        return CIContext(options: options)
    }()

    static func getCachedRenderedImage(for key: String) -> RenderedImageCache? {
        let nsKey = key as NSString
        return imageCache.object(forKey: nsKey)
    }

    static func hasNonTransparentPixels(_ cgImage: CGImage) -> Bool {
        let width = cgImage.width
        let height = cgImage.height

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let pixelData = context.data?.assumingMemoryBound(to: UInt8.self) else {
            return false
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        for y in 0..<height {
            for x in 0..<width {
                let pixelOffset = (y * width + x) * bytesPerPixel
                let alpha = pixelData[pixelOffset + 3]
                if alpha > 0 {
                    return true
                }
            }
        }
        return false
    }

    static func renderAndCacheImage(_ ciImage: CIImage, for key: String, context: CIContext) -> RenderedImageCache? {
        let nsKey = key as NSString

        if let cached = imageCache.object(forKey: nsKey) {
            return cached
        }

        let headRect = CGRect(
            x: MinecraftSkinConstants.headStartX,
            y: ciImage.extent.height - MinecraftSkinConstants.headStartY - MinecraftSkinConstants.headHeight,
            width: MinecraftSkinConstants.headWidth,
            height: MinecraftSkinConstants.headHeight
        )
        let headCropped = ciImage.cropped(to: headRect)

        let layerRect = CGRect(
            x: MinecraftSkinConstants.layerStartX,
            y: ciImage.extent.height - MinecraftSkinConstants.layerStartY - MinecraftSkinConstants.layerHeight,
            width: MinecraftSkinConstants.layerWidth,
            height: MinecraftSkinConstants.layerHeight
        )
        let layerCropped = ciImage.cropped(to: layerRect)

        guard let headCGImage = context.createCGImage(headCropped, from: headCropped.extent),
              let layerCGImage = context.createCGImage(layerCropped, from: layerCropped.extent) else {
            return nil
        }

        let hasLayerContent = hasNonTransparentPixels(layerCGImage)

        let cache = RenderedImageCache(headImage: headCGImage, layerImage: layerCGImage, hasLayerContent: hasLayerContent)
        imageCache.setObject(cache, forKey: nsKey, cost: cache.cost)
        return cache
    }

    static func clearCache() {
        imageCache.removeAllObjects()
        Logger.shared.debug("🧹 MinecraftSkinUtils 缓存已清理")
    }
}
