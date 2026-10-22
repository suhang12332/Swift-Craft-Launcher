//
//  ChunkProgressAggregatorTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ChunkProgressAggregatorTests: XCTestCase {
    func testReport_sumsAllChunks() async throws {
        let recorder = ProgressRecorder()
        let aggregator = ChunkProgressAggregator(totalSize: 1000) { written, total in
            Task { await recorder.record((written, total)) }
        }

        await aggregator.report(chunk: 0, totalWritten: 300)
        await aggregator.report(chunk: 1, totalWritten: 200)
        await aggregator.flush()

        try await Task.sleep(nanoseconds: 100_000_000)
        let last = await recorder.last
        XCTAssertEqual(last?.0, 500)
        XCTAssertEqual(last?.1, 1000)
    }

    func testReport_absoluteValuePreventsDoubleCountingOnRetry() async throws {
        let recorder = ProgressRecorder()
        let aggregator = ChunkProgressAggregator(totalSize: 1000) { written, total in
            Task { await recorder.record((written, total)) }
        }

        await aggregator.report(chunk: 0, totalWritten: 100)
        await aggregator.report(chunk: 0, totalWritten: 400)
        await aggregator.flush()

        try await Task.sleep(nanoseconds: 100_000_000)
        let last = await recorder.last
        XCTAssertEqual(last?.0, 400)
    }

    func testReport_withoutHandlerDoesNotCrash() async {
        let aggregator = ChunkProgressAggregator(totalSize: 100, progressHandler: nil)
        await aggregator.report(chunk: 0, totalWritten: 50)
        await aggregator.flush()
    }
}

private actor ProgressRecorder {
    private var value: (Int64, Int64)?

    func record(_ sample: (Int64, Int64)) {
        value = sample
    }

    var last: (Int64, Int64)? { value }
}
