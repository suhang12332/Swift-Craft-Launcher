//
//  ModInstallationCacheTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

@MainActor
final class ModInstallationCacheTests: XCTestCase {
    func testAddAndRetrieve() async {
        let cache = ModScanner.ModInstallationCache()
        await cache.addHash("hash1", to: "testGame")

        let hashes = await cache.getAllModsInstalled(for: "testGame")
        XCTAssertTrue(hashes.contains("hash1"))
    }

    func testAddMultipleHashes() async {
        let cache = ModScanner.ModInstallationCache()
        await cache.addHash("hash1", to: "game1")
        await cache.addHash("hash2", to: "game1")
        await cache.addHash("hash3", to: "game1")

        let hashes = await cache.getAllModsInstalled(for: "game1")
        XCTAssertEqual(hashes.count, 3)
        XCTAssertTrue(hashes.contains("hash1"))
        XCTAssertTrue(hashes.contains("hash2"))
        XCTAssertTrue(hashes.contains("hash3"))
    }

    func testRemoveHash() async {
        let cache = ModScanner.ModInstallationCache()
        await cache.addHash("hash1", to: "game1")
        await cache.addHash("hash2", to: "game1")
        await cache.removeHash("hash1", from: "game1")

        let hashes = await cache.getAllModsInstalled(for: "game1")
        XCTAssertFalse(hashes.contains("hash1"))
        XCTAssertTrue(hashes.contains("hash2"))
    }

    func testRemoveGame() async {
        let cache = ModScanner.ModInstallationCache()
        await cache.addHash("hash1", to: "game1")
        await cache.removeGame(gameName: "game1")

        let hashes = await cache.getAllModsInstalled(for: "game1")
        XCTAssertTrue(hashes.isEmpty)
    }

    func testSetAllModsInstalled() async {
        let cache = ModScanner.ModInstallationCache()
        let hashes: Set = ["h1", "h2", "h3"]
        await cache.setAllModsInstalled(for: "game1", hashes: hashes)

        let result = await cache.getAllModsInstalled(for: "game1")
        XCTAssertEqual(result, hashes)
    }

    func testGetEmptyGame() async {
        let cache = ModScanner.ModInstallationCache()
        let hashes = await cache.getAllModsInstalled(for: "nonexistent")
        XCTAssertTrue(hashes.isEmpty)
    }
}
