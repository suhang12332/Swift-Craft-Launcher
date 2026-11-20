//
//  ProfileStorageCalculatorTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ProfileStorageCalculatorTests: XCTestCase {
    func testProfileStorageInfo_init() {
        let info = ProfileStorageInfo(archiveCount: 10, totalSize: 1024)
        XCTAssertEqual(info.archiveCount, 10)
        XCTAssertEqual(info.totalSize, 1024)
        XCTAssertFalse(info.formattedSize.isEmpty)
    }

    func testProfileStorageInfo_equatable() {
        let a = ProfileStorageInfo(archiveCount: 5, totalSize: 500)
        let b = ProfileStorageInfo(archiveCount: 5, totalSize: 500)
        let c = ProfileStorageInfo(archiveCount: 5, totalSize: 1000)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testProfileStorageInfo_formatFileSize_zero() {
        let result = ProfileStorageInfo.formatFileSize(0)
        XCTAssertFalse(result.isEmpty)
    }

    func testProfileStorageInfo_formatFileSize_nonZero() {
        let result = ProfileStorageInfo.formatFileSize(1024 * 1024)
        XCTAssertFalse(result.isEmpty)
    }
}
