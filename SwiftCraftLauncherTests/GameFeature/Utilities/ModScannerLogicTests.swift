//
//  ModScannerLogicTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class ModScannerLogicTests: XCTestCase {

    private let scanner = ModScanner(errorHandler: GlobalErrorHandler.shared)

    func testIsModsDirectory_mods() {
        let url = URL(fileURLWithPath: "/path/to/game/mods")
        XCTAssertTrue(scanner.isModsDirectory(url))
    }

    func testIsModsDirectory_Mods_caseInsensitive() {
        let url = URL(fileURLWithPath: "/path/to/game/Mods")
        XCTAssertTrue(scanner.isModsDirectory(url))
    }

    func testIsModsDirectory_MODS_caseInsensitive() {
        let url = URL(fileURLWithPath: "/path/to/game/MODS")
        XCTAssertTrue(scanner.isModsDirectory(url))
    }

    func testIsModsDirectory_notMods() {
        let url = URL(fileURLWithPath: "/path/to/game/resourcepacks")
        XCTAssertFalse(scanner.isModsDirectory(url))
    }

    func testIsModsDirectory_modsSubdirectory() {
        let url = URL(fileURLWithPath: "/path/to/game/mods/subdir")
        XCTAssertFalse(scanner.isModsDirectory(url))
    }

    func testIsModsDirectory_modsInName() {
        let url = URL(fileURLWithPath: "/path/to/game/mods_backup")
        XCTAssertFalse(scanner.isModsDirectory(url))
    }

    func testExtractGameName_standard() {
        let url = URL(fileURLWithPath: "/Users/user/.minecraft/games/MyGame/mods")
        XCTAssertEqual(scanner.extractGameName(from: url), "MyGame")
    }

    func testExtractGameName_simplePath() {
        let url = URL(fileURLWithPath: "/games/TestGame/mods")
        XCTAssertEqual(scanner.extractGameName(from: url), "TestGame")
    }

    func testExtractGameName_withSpaces() {
        let url = URL(fileURLWithPath: "/path/to/My Cool Game/mods")
        XCTAssertEqual(scanner.extractGameName(from: url), "My Cool Game")
    }

    func testExtractGameName_deepNested() {
        let url = URL(fileURLWithPath: "/a/b/c/d/mods")
        XCTAssertEqual(scanner.extractGameName(from: url), "d")
    }

    func testCalculatePageRange_singleItem() {
        let result = scanner.calculatePageRange(totalCount: 1, page: 1, pageSize: 10)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.startIndex, 0)
        XCTAssertEqual(result?.endIndex, 1)
        XCTAssertFalse(result?.hasMore ?? true)
    }

    func testCalculatePageRange_exactPageSize() {
        let result = scanner.calculatePageRange(totalCount: 20, page: 1, pageSize: 20)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.startIndex, 0)
        XCTAssertEqual(result?.endIndex, 20)
        XCTAssertFalse(result?.hasMore ?? true)
    }

    func testCalculatePageRange_pageOneOnly() {
        let result = scanner.calculatePageRange(totalCount: 5, page: 1, pageSize: 10)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.startIndex, 0)
        XCTAssertEqual(result?.endIndex, 5)
        XCTAssertFalse(result?.hasMore ?? true)
    }

    func testCalculatePageRange_pageTwoWithRemainder() {
        let result = scanner.calculatePageRange(totalCount: 25, page: 2, pageSize: 10)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.startIndex, 10)
        XCTAssertEqual(result?.endIndex, 20)
        XCTAssertTrue(result?.hasMore ?? false)
    }

    func testCalculatePageRange_lastPagePartial() {
        let result = scanner.calculatePageRange(totalCount: 25, page: 3, pageSize: 10)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.startIndex, 20)
        XCTAssertEqual(result?.endIndex, 25)
        XCTAssertFalse(result?.hasMore ?? true)
    }

    func testCalculatePageRange_negativePage() {
        let result = scanner.calculatePageRange(totalCount: 10, page: -1, pageSize: 5)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.startIndex, 0)
        XCTAssertEqual(result?.endIndex, 5)
    }

    func testCalculatePageRange_negativePageSize() {
        let result = scanner.calculatePageRange(totalCount: 10, page: 1, pageSize: -1)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.startIndex, 0)
        XCTAssertEqual(result?.endIndex, 1)
    }
}
