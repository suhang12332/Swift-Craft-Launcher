//
//  DownloadResumptionStoreTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class DownloadResumptionStoreTests: XCTestCase {
    private var key: String!

    override func setUp() {
        super.setUp()
        key = "test-\(UUID().uuidString)"
        DownloadResumptionStore.remove(key: key)
    }

    override func tearDown() {
        DownloadResumptionStore.remove(key: key)
        super.tearDown()
    }

    func testSaveAndLoad_roundTrip() {
        let state = DownloadResumptionState(
            url: "https://example.com/big.jar",
            etag: "\"abc\"",
            lastModified: nil,
            fileSize: 1024,
            chunkCount: 2,
            chunks: [0: 512, 1: 256],
            updatedAt: Date(),
        )

        DownloadResumptionStore.save(state, key: key)
        let loaded = DownloadResumptionStore.load(key: key)

        XCTAssertEqual(loaded?.fileSize, 1024)
        XCTAssertEqual(loaded?.chunks[0], 512)
        XCTAssertEqual(loaded?.chunks[1], 256)
    }

    func testLoad_missingReturnsNil() {
        XCTAssertNil(DownloadResumptionStore.load(key: "does-not-exist-\(UUID().uuidString)"))
    }

    func testMatches_rejectsChangedFileSizeOrLayout() {
        let state = DownloadResumptionState(
            url: "https://example.com/big.jar",
            etag: "\"abc\"",
            lastModified: nil,
            fileSize: 1024,
            chunkCount: 2,
            chunks: [:],
            updatedAt: Date(),
        )

        XCTAssertTrue(state.matches(etag: "\"abc\"", fileSize: 1024, chunkCount: 2))
        XCTAssertFalse(state.matches(etag: "\"abc\"", fileSize: 2048, chunkCount: 2))
        XCTAssertFalse(state.matches(etag: "\"abc\"", fileSize: 1024, chunkCount: 4))
        XCTAssertFalse(state.matches(etag: "\"other\"", fileSize: 1024, chunkCount: 2))
    }

    func testRemove_deletesBothArtifacts() throws {
        let state = DownloadResumptionState(
            url: "https://example.com/big.jar",
            etag: nil,
            lastModified: nil,
            fileSize: 10,
            chunkCount: 1,
            chunks: [:],
            updatedAt: Date(),
        )
        DownloadResumptionStore.save(state, key: key)
        try Data(count: 10).write(to: DownloadResumptionStore.partFileURL(for: key))

        DownloadResumptionStore.remove(key: key)

        XCTAssertNil(DownloadResumptionStore.load(key: key))
        XCTAssertFalse(FileManager.default.fileExists(atPath: DownloadResumptionStore.partFileURL(for: key).path))
    }

    func testCleanup_removesOnlyExpiredEntries() throws {
        let expiredKey = "expired-\(UUID().uuidString)"
        let state = DownloadResumptionState(
            url: "https://example.com/big.jar",
            etag: nil,
            lastModified: nil,
            fileSize: 10,
            chunkCount: 1,
            chunks: [:],
            updatedAt: Date(),
        )
        DownloadResumptionStore.save(state, key: expiredKey)
        defer { DownloadResumptionStore.remove(key: expiredKey) }

        let metadataURL = DownloadResumptionStore.metadataFileURL(for: expiredKey)
        let staleDate = Date().addingTimeInterval(-DownloadResumptionStore.retentionInterval - 60)
        try FileManager.default.setAttributes([.modificationDate: staleDate], ofItemAtPath: metadataURL.path)

        DownloadResumptionStore.save(state, key: key)
        DownloadResumptionStore.cleanup()

        XCTAssertNil(DownloadResumptionStore.load(key: expiredKey))
        XCTAssertNotNil(DownloadResumptionStore.load(key: key))
    }
}
