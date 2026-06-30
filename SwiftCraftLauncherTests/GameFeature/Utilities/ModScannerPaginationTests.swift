//
//  ModScannerPaginationTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ModScannerPaginationTests: XCTestCase {
    func testCalculatePageRange_normalPage() {
        let scanner = ModScanner.shared
        let result = scanner.calculatePageRange(totalCount: 100, page: 1, pageSize: 20)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.startIndex, 0)
        XCTAssertEqual(result?.endIndex, 20)
        XCTAssertTrue(result?.hasMore ?? false)
    }

    func testCalculatePageRange_lastPage() {
        let scanner = ModScanner.shared
        let result = scanner.calculatePageRange(totalCount: 25, page: 2, pageSize: 20)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.startIndex, 20)
        XCTAssertEqual(result?.endIndex, 25)
        XCTAssertFalse(result?.hasMore ?? true)
    }

    func testCalculatePageRange_emptyTotal() {
        let scanner = ModScanner.shared
        let result = scanner.calculatePageRange(totalCount: 0, page: 1, pageSize: 20)

        XCTAssertNil(result)
    }

    func testCalculatePageRange_pageBeyondTotal() {
        let scanner = ModScanner.shared
        let result = scanner.calculatePageRange(totalCount: 10, page: 5, pageSize: 20)

        XCTAssertNil(result)
    }

    func testCalculatePageRange_zeroPageSize() {
        let scanner = ModScanner.shared
        let result = scanner.calculatePageRange(totalCount: 10, page: 1, pageSize: 0)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.startIndex, 0)
        XCTAssertEqual(result?.endIndex, 1)
    }

    func testCalculatePageRange_pageZero() {
        let scanner = ModScanner.shared
        let result = scanner.calculatePageRange(totalCount: 10, page: 0, pageSize: 5)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.startIndex, 0)
        XCTAssertEqual(result?.endIndex, 5)
    }
}
