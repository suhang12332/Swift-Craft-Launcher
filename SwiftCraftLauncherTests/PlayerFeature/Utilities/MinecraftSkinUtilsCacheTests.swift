//
//  MinecraftSkinUtilsCacheTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class MinecraftSkinUtilsCacheTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MinecraftSkinUtils.clearCache()
    }

    override func tearDown() {
        MinecraftSkinUtils.clearCache()
        super.tearDown()
    }

    func testClearCache_removesAllObjects() {
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
            hasLayerContent: false,
        )
        let key = "test-clear-key"
        MinecraftSkinUtils.imageCache.setObject(
            cacheEntry,
            forKey: key as NSString,
            cost: cacheEntry.cost,
        )

        XCTAssertNotNil(MinecraftSkinUtils.getCachedRenderedImage(for: key))
        MinecraftSkinUtils.clearCache()
        XCTAssertNil(MinecraftSkinUtils.getCachedRenderedImage(for: key))
    }

    func testGetCachedRenderedImage_missReturnsNil() {
        let result = MinecraftSkinUtils.getCachedRenderedImage(for: "nonexistent-key")
        XCTAssertNil(result)
    }

    func testGetCachedRenderedImage_hitReturnsCached() {
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
            hasLayerContent: false,
        )
        let key = "test-hit-key"
        MinecraftSkinUtils.imageCache.setObject(
            cacheEntry,
            forKey: key as NSString,
            cost: cacheEntry.cost,
        )

        let result = MinecraftSkinUtils.getCachedRenderedImage(for: key)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.headImage.width, 8)
    }

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
            hasLayerContent: true,
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
            hasLayerContent: false,
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
            hasLayerContent: true,
        )
        XCTAssertTrue(cache.hasLayerContent)
    }

    private func createTestCGImage(size: CGSize) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
        ) else {
            return nil
        }
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        return context.makeImage()
    }
}
