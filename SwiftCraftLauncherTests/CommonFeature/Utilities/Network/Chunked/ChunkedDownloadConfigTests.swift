//
//  ChunkedDownloadConfigTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ChunkedDownloadConfigTests: XCTestCase {
    func testFilesBelowTheThresholdAreNotWorthChunking() {
        XCTAssertFalse(ChunkedDownloadConfig.isWorthChunking(fileSize: 0))
        XCTAssertFalse(ChunkedDownloadConfig.isWorthChunking(fileSize: 1024))
        XCTAssertFalse(ChunkedDownloadConfig.isWorthChunking(fileSize: ChunkedDownloadConfig.minimumFileSize - 1))
    }

    func testFilesAtOrAboveTheThresholdAreWorthChunking() {
        XCTAssertTrue(ChunkedDownloadConfig.isWorthChunking(fileSize: ChunkedDownloadConfig.minimumFileSize))
        XCTAssertTrue(ChunkedDownloadConfig.isWorthChunking(fileSize: ChunkedDownloadConfig.minimumFileSize * 4))
    }

    /// A typical mod is far below the threshold, so a modpack install probes
    /// only the handful of large files instead of every entry in the index.
    func testTypicalModSizesStayOnTheSingleStreamPath() {
        let typicalModSizes: [Int64] = [
            48 * 1024,
            250 * 1024,
            1 * 1024 * 1024,
            5 * 1024 * 1024,
        ]
        for size in typicalModSizes {
            XCTAssertFalse(
                ChunkedDownloadConfig.isWorthChunking(fileSize: size),
                "\(size) bytes should not trigger a chunking probe",
            )
        }
    }
}
