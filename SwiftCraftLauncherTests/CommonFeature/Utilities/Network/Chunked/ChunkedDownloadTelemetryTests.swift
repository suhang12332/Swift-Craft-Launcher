//
//  ChunkedDownloadTelemetryTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ChunkedDownloadTelemetryTests: XCTestCase {
    private let slowHost = "slow.example.com"

    override func setUp() {
        super.setUp()
        ChunkedDownloadTelemetry.reset()
    }

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
        ChunkedDownloadTelemetry.markIneffective(host: slowHost)
        ChunkedDownloadTelemetry.reset()

        XCTAssertFalse(ChunkedDownloadTelemetry.isChunkingDisabled(forHost: slowHost))
    }

    /// One slow transfer proves nothing: the file may simply have shared the pipe
    /// with a queue of others. Pinning on a single sample disabled working hosts.
    func testRecordIneffective_needsAStreakBeforePinning() {
        ChunkedDownloadTelemetry.recordIneffective(host: slowHost)
        XCTAssertFalse(ChunkedDownloadTelemetry.isChunkingDisabled(forHost: slowHost))
        ChunkedDownloadTelemetry.recordIneffective(host: slowHost)
        XCTAssertFalse(ChunkedDownloadTelemetry.isChunkingDisabled(forHost: slowHost))

        ChunkedDownloadTelemetry.recordIneffective(host: slowHost)
        XCTAssertTrue(ChunkedDownloadTelemetry.isChunkingDisabled(forHost: slowHost))
    }

    func testRecordEffective_clearsStreakAndPin() {
        for _ in 0 ..< 3 { ChunkedDownloadTelemetry.recordIneffective(host: slowHost) }
        XCTAssertTrue(ChunkedDownloadTelemetry.isChunkingDisabled(forHost: slowHost))

        ChunkedDownloadTelemetry.recordEffective(host: slowHost)
        XCTAssertFalse(ChunkedDownloadTelemetry.isChunkingDisabled(forHost: slowHost))
    }

    /// Hosts pinned by the old one-sample rule were stored as a plain array.
    /// Reading that shape as a dictionary yields nothing, so those hosts recover.
    func testLegacyHostArray_isIgnored() {
        UserDefaults.standard.set([slowHost], forKey: "chunkedDownloadIneffectiveHosts")
        XCTAssertFalse(ChunkedDownloadTelemetry.isChunkingDisabled(forHost: slowHost))
    }

    func testPin_expiresSoAHostGetsAnotherChance() {
        UserDefaults.standard.set(
            [slowHost: Date().addingTimeInterval(-25 * 3600).timeIntervalSince1970],
            forKey: "chunkedDownloadIneffectiveHosts",
        )
        XCTAssertFalse(ChunkedDownloadTelemetry.isChunkingDisabled(forHost: slowHost))
    }
}
