import SwiftUI
import CoreImage
import Foundation

extension MinecraftSkinUtils {

    struct CacheStats {
        var hits: Int = 0
        var misses: Int = 0
        var evictions: Int = 0

        var hitRate: Double {
            let total = hits + misses
            return total > 0 ? Double(hits) / Double(total) : 0.0
        }
    }

    static let imageCache: NSCache<NSString, RenderedImageCache> = {
        let cache = NSCache<NSString, RenderedImageCache>()
        cache.countLimit = MinecraftSkinConstants.maxCacheSize
        cache.totalCostLimit = MinecraftSkinConstants.maxCacheMemory
        cache.name = "MinecraftSkinCache"
        return cache
    }()

    static let sharedURLSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = MinecraftSkinConstants.networkTimeout
        config.timeoutIntervalForResource = MinecraftSkinConstants.networkTimeout
        config.requestCachePolicy = .useProtocolCachePolicy
        config.urlCache = .shared
        return URLSession(configuration: config)
    }()

    static var cacheStats = CacheStats()

    static var memoryObserverSetup = false
    static let memoryObserverQueue = DispatchQueue(label: "com.swiftcraftlauncher.skincache.memory")

    static let ciContext: CIContext = {
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: true,
            .cacheIntermediates: false,
            .name: "MinecraftSkinProcessor",
        ]
        let context = CIContext(options: options)
        setupMemoryPressureObserverOnce()
        return context
    }()

    static func getCachedRenderedImage(for key: String) -> RenderedImageCache? {
        let nsKey = key as NSString
        if let cache = imageCache.object(forKey: nsKey) {
            cacheStats.hits += 1
            return cache
        } else {
            cacheStats.misses += 1
            return nil
        }
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
        cacheStats = CacheStats()
        Logger.shared.debug("🧹 MinecraftSkinUtils 缓存已清理")
    }

    static func getCacheInfo() -> (countLimit: Int, memoryLimit: Int, hitRate: Double) {
        (
            countLimit: imageCache.countLimit,
            memoryLimit: imageCache.totalCostLimit,
            hitRate: cacheStats.hitRate
        )
    }

    static func getCacheStats() -> (hits: Int, misses: Int, hitRate: Double) {
        (
            hits: cacheStats.hits,
            misses: cacheStats.misses,
            hitRate: cacheStats.hitRate
        )
    }

    static func setupMemoryPressureObserverOnce() {
        memoryObserverQueue.sync {
            guard !memoryObserverSetup else { return }
            memoryObserverSetup = true
        }
    }
}
