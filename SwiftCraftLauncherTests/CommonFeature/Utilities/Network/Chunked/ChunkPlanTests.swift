//
//  ChunkPlanTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ChunkPlanTests: XCTestCase {
    func testMake_emptyForNonPositiveSize() {
        XCTAssertTrue(ChunkPlan.make(fileSize: 0).isEmpty)
        XCTAssertTrue(ChunkPlan.make(fileSize: -1).isEmpty)
    }

    func testMake_smallFileYieldsSingleChunk() {
        let chunks = ChunkPlan.make(fileSize: 1024, chunkSize: 1024 * 1024, maxChunks: 8)
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks.first?.lowerBound, 0)
        XCTAssertEqual(chunks.first?.upperBound, 1023)
        XCTAssertEqual(chunks.first?.length, 1024)
    }

    func testMake_respectsMaxChunks() {
        let chunks = ChunkPlan.make(fileSize: 256 * 1024 * 1024, chunkSize: 1024 * 1024, maxChunks: 4)
        XCTAssertEqual(chunks.count, 4)
    }

    func testMake_chunksAreContiguousAndComplete() {
        let fileSize: Int64 = 10 * 1024 * 1024 + 7
        let chunks = ChunkPlan.make(fileSize: fileSize, chunkSize: 1024 * 1024, maxChunks: 8)

        XCTAssertEqual(chunks.first?.lowerBound, 0)
        XCTAssertEqual(chunks.last?.upperBound, fileSize - 1)
        XCTAssertEqual(chunks.map(\.length).reduce(0, +), fileSize)

        for (previous, current) in zip(chunks, chunks.dropFirst()) {
            XCTAssertEqual(previous.upperBound + 1, current.lowerBound)
            XCTAssertEqual(previous.index + 1, current.index)
        }
    }

    func testRangeHeaderValue_format() {
        let chunk = DownloadChunk(index: 0, lowerBound: 0, upperBound: 4_194_303)
        XCTAssertEqual(chunk.rangeHeaderValue, "bytes=0-4194303")
    }
}
