import XCTest
@testable import SwiftCraftLauncher

final class MinecraftSkinUtilsCacheTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MinecraftSkinUtils.clearCache()
    }

    override func tearDown() {
        MinecraftSkinUtils.clearCache()
        super.tearDown()
    }

    // MARK: - CacheStats

    func testCacheStats_initialHitRate_isZero() {
        let stats = MinecraftSkinUtils.CacheStats()
        XCTAssertEqual(stats.hitRate, 0.0)
    }

    func testCacheStats_hitsOnly_hitRateIsOne() {
        var stats = MinecraftSkinUtils.CacheStats()
        stats.hits = 10
        XCTAssertEqual(stats.hitRate, 1.0)
    }

    func testCacheStats_mixedHitsMisses_correctRate() {
        var stats = MinecraftSkinUtils.CacheStats()
        stats.hits = 3
        stats.misses = 7
        XCTAssertEqual(stats.hitRate, 0.3, accuracy: 0.001)
    }

    func testCacheStats_allMisses_hitRateIsZero() {
        var stats = MinecraftSkinUtils.CacheStats()
        stats.misses = 5
        XCTAssertEqual(stats.hitRate, 0.0)
    }

    // MARK: - Cache Operations

    func testClearCache_resetsStats() {
        MinecraftSkinUtils.cacheStats.hits = 5
        MinecraftSkinUtils.cacheStats.misses = 3
        MinecraftSkinUtils.clearCache()
        let stats = MinecraftSkinUtils.getCacheStats()
        XCTAssertEqual(stats.hits, 0)
        XCTAssertEqual(stats.misses, 0)
        XCTAssertEqual(stats.hitRate, 0.0)
    }

    func testGetCacheInfo_returnsCorrectLimits() {
        let info = MinecraftSkinUtils.getCacheInfo()
        XCTAssertEqual(info.countLimit, MinecraftSkinConstants.maxCacheSize)
        XCTAssertEqual(info.memoryLimit, MinecraftSkinConstants.maxCacheMemory)
    }

    func testGetCacheStats_initialValues() {
        let stats = MinecraftSkinUtils.getCacheStats()
        XCTAssertEqual(stats.hits, 0)
        XCTAssertEqual(stats.misses, 0)
    }

    func testGetCachedRenderedImage_missIncrementsMissCount() {
        _ = MinecraftSkinUtils.getCachedRenderedImage(for: "nonexistent-key")
        let stats = MinecraftSkinUtils.getCacheStats()
        XCTAssertEqual(stats.misses, 1)
    }

    func testGetCachedRenderedImage_hitIncrementsHitCount() {
        let headSize = CGSize(width: 8, height: 8)
        let layerSize = CGSize(width: 8, height: 8)
        guard let headImage = createTestCGImage(size: headSize),
              let layerImage = createTestCGImage(size: layerSize) else {
            XCTFail("Failed to create test images")
            return
        }
        let cacheEntry = RenderedImageCache(
            headImage: headImage,
            layerImage: layerImage,
            hasLayerContent: false
        )
        let key = "test-hit-key"
        MinecraftSkinUtils.imageCache.setObject(
            cacheEntry,
            forKey: key as NSString,
            cost: cacheEntry.cost
        )

        _ = MinecraftSkinUtils.getCachedRenderedImage(for: key)
        let stats = MinecraftSkinUtils.getCacheStats()
        XCTAssertEqual(stats.hits, 1)
    }

    // MARK: - RenderedImageCache

    func testRenderedImageCache_costCalculation() {
        let width = 8
        let height = 8
        guard let headImage = createTestCGImage(size: CGSize(width: width, height: height)),
              let layerImage = createTestCGImage(size: CGSize(width: width, height: height)) else {
            XCTFail("Failed to create test images")
            return
        }
        let cache = RenderedImageCache(
            headImage: headImage,
            layerImage: layerImage,
            hasLayerContent: true
        )
        let expectedCost = width * height * 4 * 2 + 2 * 1024
        XCTAssertEqual(cache.cost, expectedCost)
    }

    func testRenderedImageCache_properties() {
        guard let headImage = createTestCGImage(size: CGSize(width: 4, height: 4)),
              let layerImage = createTestCGImage(size: CGSize(width: 4, height: 4)) else {
            XCTFail("Failed to create test images")
            return
        }
        let cache = RenderedImageCache(
            headImage: headImage,
            layerImage: layerImage,
            hasLayerContent: false
        )
        XCTAssertFalse(cache.hasLayerContent)
        XCTAssertEqual(cache.headImage.width, 4)
        XCTAssertEqual(cache.layerImage.width, 4)
    }

    func testRenderedImageCache_hasLayerContent_true() {
        guard let headImage = createTestCGImage(size: CGSize(width: 4, height: 4)),
              let layerImage = createTestCGImage(size: CGSize(width: 4, height: 4)) else {
            XCTFail("Failed to create test images")
            return
        }
        let cache = RenderedImageCache(
            headImage: headImage,
            layerImage: layerImage,
            hasLayerContent: true
        )
        XCTAssertTrue(cache.hasLayerContent)
    }

    // MARK: - Helpers

    private func createTestCGImage(size: CGSize) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        return context.makeImage()
    }
}
