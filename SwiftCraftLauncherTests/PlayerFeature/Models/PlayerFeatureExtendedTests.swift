//
//  PlayerFeatureExtendedTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class PlayerFeatureExtendedTests: XCTestCase {
    func testSkinSelectionStore_select_setsId() {
        let store = SkinSelectionStore()
        store.select("player1")
        XCTAssertEqual(store.selectedPlayerId, "player1")
    }

    func testSkinSelectionStore_select_nil_clearsId() {
        let store = SkinSelectionStore()
        store.select("player1")
        store.select(nil)
        XCTAssertNil(store.selectedPlayerId)
    }

    func testSkinSelectionStore_select_sameId_noChange() {
        let store = SkinSelectionStore()
        store.select("player1")
        store.select("player1")
        XCTAssertEqual(store.selectedPlayerId, "player1")
    }

    func testSkinSelectionStore_initialValue_isNil() {
        let store = SkinSelectionStore()
        XCTAssertNil(store.selectedPlayerId)
    }

    func testMinecraftSkinConstants_headRegion() {
        XCTAssertEqual(MinecraftSkinConstants.headStartX, 8)
        XCTAssertEqual(MinecraftSkinConstants.headStartY, 8)
        XCTAssertEqual(MinecraftSkinConstants.headWidth, 8)
        XCTAssertEqual(MinecraftSkinConstants.headHeight, 8)
    }

    func testMinecraftSkinConstants_layerRegion() {
        XCTAssertEqual(MinecraftSkinConstants.layerStartX, 40)
        XCTAssertEqual(MinecraftSkinConstants.layerStartY, 8)
        XCTAssertEqual(MinecraftSkinConstants.layerWidth, 8)
        XCTAssertEqual(MinecraftSkinConstants.layerHeight, 8)
    }

    func testMinecraftSkinConstants_cacheSettings() {
        XCTAssertEqual(MinecraftSkinConstants.maxCacheSize, 100)
        XCTAssertEqual(MinecraftSkinConstants.maxCacheMemory, 2 * 1024 * 1024)
        XCTAssertEqual(MinecraftSkinConstants.networkTimeout, 10.0)
        XCTAssertEqual(MinecraftSkinConstants.padding, 6)
    }

    func testPlayer_authXuid_withCredential() {
        let profile = UserProfile(id: "uuid", name: "Test", avatar: "steve")
        let credential = AuthCredential(userId: "uuid", accessToken: "token", refreshToken: "refresh", xuid: "xuid123")
        let player = Player(profile: profile, credential: credential)
        XCTAssertEqual(player.authXuid, "xuid123")
    }

    func testPlayer_authXuid_withoutCredential() {
        let profile = UserProfile(id: "uuid", name: "Test", avatar: "steve")
        let player = Player(profile: profile, credential: nil)
        XCTAssertEqual(player.authXuid, "")
    }

    func testSkinModel_invalidRawValue_returnsNil() {
        XCTAssertNil(PlayerSkinService.PublicSkinInfo.SkinModel(rawValue: "INVALID"))
    }

    func testSkinModel_allCases() {
        let allCases = PlayerSkinService.PublicSkinInfo.SkinModel.allCases
        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.classic))
        XCTAssertTrue(allCases.contains(.slim))
    }

    func testSkinLibraryItem_fileURL_endsWithPNG() {
        let item = SkinLibraryItem(originalFileName: "skin.png", sha1: "abc123", model: .classic, lastUsedAt: Date())
        XCTAssertTrue(item.fileURL.path.hasSuffix(".png"))
    }

    func testSkinLibraryItem_differentSha1_differentId() {
        let item1 = SkinLibraryItem(originalFileName: "skin.png", sha1: "abc", model: .classic, lastUsedAt: Date())
        let item2 = SkinLibraryItem(originalFileName: "skin.png", sha1: "def", model: .classic, lastUsedAt: Date())
        XCTAssertNotEqual(item1.id, item2.id)
    }

    func testHasNonTransparentPixels_opaqueImage_returnsTrue() {
        let size = CGSize(width: 2, height: 2)
        guard let image = createTestCGImage(size: size, alpha: 1.0) else {
            XCTFail("Failed to create test image")
            return
        }
        XCTAssertTrue(MinecraftSkinUtils.hasNonTransparentPixels(image))
    }

    func testHasNonTransparentPixels_transparentImage_returnsFalse() {
        let size = CGSize(width: 2, height: 2)
        guard let image = createTestCGImage(size: size, alpha: 0.0) else {
            XCTFail("Failed to create test image")
            return
        }
        XCTAssertFalse(MinecraftSkinUtils.hasNonTransparentPixels(image))
    }

    func testHasNonTransparentPixels_mixedImage_returnsTrue() {
        let size = CGSize(width: 2, height: 2)
        guard let image = createTestCGImageWithMixedAlpha(size: size) else {
            XCTFail("Failed to create test image")
            return
        }
        XCTAssertTrue(MinecraftSkinUtils.hasNonTransparentPixels(image))
    }

    func testRenderedImageCache_cost_formula() {
        let headSize = CGSize(width: 8, height: 8)
        let layerSize = CGSize(width: 4, height: 4)
        guard let headImage = createTestCGImage(size: headSize, alpha: 1.0),
              let layerImage = createTestCGImage(size: layerSize, alpha: 1.0) else {
            XCTFail("Failed to create test images")
            return
        }
        let cache = RenderedImageCache(headImage: headImage, layerImage: layerImage, hasLayerContent: false)
        let expectedCost = 8 * 8 * 4 + 4 * 4 * 4 + 2 * 1024
        XCTAssertEqual(cache.cost, expectedCost)
    }

    private func createTestCGImage(size: CGSize, alpha: CGFloat) -> CGImage? {
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
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: alpha))
        context.fill(CGRect(origin: .zero, size: size))
        return context.makeImage()
    }

    private func createTestCGImageWithMixedAlpha(size: CGSize) -> CGImage? {
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
        // First pixel opaque, second pixel transparent
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.0))
        context.fill(CGRect(x: 1, y: 0, width: 1, height: 1))
        return context.makeImage()
    }
}
