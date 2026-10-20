//
//  ChunkedDownloadTelemetryTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ChunkedDownloadTelemetryTests: XCTestCase {
    override func tearDown() {
        ChunkedDownloadTelemetry.reset()
        super.tearDown()
    }

    func testUnknownHost_isNotDisabled() {
        XCTAssertFalse(ChunkedDownloadTelemetry.isChunkingDisabled(forHost: "cdn.example.com"))
    }

    func testMarkIneffective_disablesHostOnly() {
        ChunkedDownloadTelemetry.markIneffective(host: "slow.example.com")

        XCTAssertTrue(ChunkedDownloadTelemetry.isChunkingDisabled(forHost: "slow.example.com"))
        XCTAssertFalse(ChunkedDownloadTelemetry.isChunkingDisabled(forHost: "fast.example.com"))
    }

    func testNilOrEmptyHost_isIgnored() {
        ChunkedDownloadTelemetry.markIneffective(host: nil)
        ChunkedDownloadTelemetry.markIneffective(host: "")

        XCTAssertFalse(ChunkedDownloadTelemetry.isChunkingDisabled(forHost: nil))
        XCTAssertFalse(ChunkedDownloadTelemetry.isChunkingDisabled(forHost: ""))
    }

    func testReset_clearsAllHosts() {
        ChunkedDownloadTelemetry.markIneffective(host: "slow.example.com")
        ChunkedDownloadTelemetry.reset()

        XCTAssertFalse(ChunkedDownloadTelemetry.isChunkingDisabled(forHost: "slow.example.com"))
    }
}
