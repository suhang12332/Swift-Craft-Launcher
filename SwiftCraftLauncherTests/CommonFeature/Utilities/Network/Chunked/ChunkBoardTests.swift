//
//  ChunkBoardTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ChunkBoardTests: XCTestCase {
    private func board(
        fileSize: Int64,
        maxChunks: Int,
        reservedSlots: Int,
        progress: (Int) -> Int64,
    ) -> (ChunkBoard, [DownloadChunk], [Int: ChunkWriteCursor]) {
        let chunks = ChunkPlan.make(fileSize: fileSize, maxChunks: maxChunks, reservedSlots: reservedSlots)
        var cursors: [Int: ChunkWriteCursor] = [:]
        for chunk in chunks {
            cursors[chunk.index] = ChunkWriteCursor(written: progress(chunk.index), capacity: chunk.length)
        }
        return (ChunkBoard(chunks: chunks, cursors: cursors, maxChunks: maxChunks), chunks, cursors)
    }

    func testInitialPlanReservesStealSlots() {
        let chunks = ChunkPlan.make(fileSize: 40 * 1024 * 1024, maxChunks: 6, reservedSlots: 2)
        XCTAssertEqual(chunks.count, 4)
    }

    func testInitialPlanFillsUpWhenTheFileIsSmall() {
        let chunks = ChunkPlan.make(fileSize: 9 * 1024 * 1024, maxChunks: 6, reservedSlots: 2)
        XCTAssertEqual(chunks.count, 3)
    }

    func testSteal_skippedWhenChunksProgressEvenly() async {
        let (board, chunks, _) = board(fileSize: 40 * 1024 * 1024, maxChunks: 6, reservedSlots: 2) { _ in 0 }
        XCTAssertEqual(chunks.count, 4)
        let stolen = await board.steal()
        XCTAssertNil(stolen)
    }

    func testSteal_skippedWhenEverythingIsDone() async {
        let (board, chunks, _) = board(fileSize: 40 * 1024 * 1024, maxChunks: 6, reservedSlots: 2) { index in
            _ = index
            return 10 * 1024 * 1024
        }
        XCTAssertEqual(chunks.count, 4)
        let stolen = await board.steal()
        XCTAssertNil(stolen)
    }

    func testSteal_skippedBelowTheMinimumSize() async {
        let (board, _, _) = board(fileSize: 10 * 1024 * 1024, maxChunks: 6, reservedSlots: 2) { index in
            index == 0 ? Int64(2.5 * 1024 * 1024) - 500 * 1024 : 3 * 1024 * 1024
        }
        let stolen = await board.steal()
        XCTAssertNil(stolen)
    }

    func testSteal_skippedWhenTheTailWouldBeTooSmall() async {
        // 1.5 MB left: 40% of that is 600 KB, under the 1 MB floor.
        let (board, _, _) = board(fileSize: 10 * 1024 * 1024, maxChunks: 6, reservedSlots: 2) { index in
            index == 0 ? Int64(2.5 * 1024 * 1024) - 1536 * 1024 : 3 * 1024 * 1024
        }
        let stolen = await board.steal()
        XCTAssertNil(stolen)
    }

    func testSteal_handsTheStragglerTailToANewChunk() async {
        let (board, chunks, cursors) = board(fileSize: 40 * 1024 * 1024, maxChunks: 6, reservedSlots: 2) { index in
            index == 3 ? Int64(100 * 1024) : 10 * 1024 * 1024
        }

        guard let stolen = await board.steal() else {
            return XCTFail("expected a steal")
        }
        guard let victimCursor = cursors[3] else {
            return XCTFail("missing victim cursor")
        }
        let victim = chunks[3]

        XCTAssertEqual(stolen.chunk.index, 4)
        // Contiguous: the new chunk starts exactly where the victim now ends.
        XCTAssertEqual(stolen.chunk.lowerBound, victim.lowerBound + victimCursor.capacity)
        // No overlap: the victim had already written past its new end.
        XCTAssertGreaterThan(stolen.chunk.lowerBound, victim.lowerBound + victimCursor.written)
        // The tail still reaches the victim's original end.
        XCTAssertEqual(stolen.chunk.upperBound, victim.upperBound)
        // Nothing is lost or double counted.
        XCTAssertEqual(victimCursor.capacity + stolen.cursor.capacity, victim.length)
        let chunkCount = await board.chunkCount
        XCTAssertEqual(chunkCount, 5)
    }

    func testSteal_keepsSplittingUntilTheCap() async {
        let (board, _, _) = board(fileSize: 40 * 1024 * 1024, maxChunks: 6, reservedSlots: 2) { index in
            index == 3 ? Int64(100 * 1024) : 10 * 1024 * 1024
        }
        var steals = 0
        while await board.steal() != nil { steals += 1 }
        XCTAssertEqual(steals, 2)
        let chunkCount = await board.chunkCount
        XCTAssertEqual(chunkCount, 6)
    }

    func testProgressSnapshotIncludesStolenChunks() async {
        let (board, _, _) = board(fileSize: 40 * 1024 * 1024, maxChunks: 6, reservedSlots: 2) { index in
            index == 3 ? Int64(100 * 1024) : 10 * 1024 * 1024
        }
        _ = await board.steal()
        let snapshot = await board.progressSnapshot()
        XCTAssertTrue(snapshot.contains { $0.index == 4 })
    }
}
