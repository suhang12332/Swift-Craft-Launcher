//
//  ChunkWriteCursorTests.swift
//  SwiftCraftLauncherTests
//
//  (c) 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ChunkWriteCursorTests: XCTestCase {
    func testReserveClampsAtCapacity() {
        let cursor = ChunkWriteCursor(written: 0, capacity: 1000)
        XCTAssertEqual(cursor.reserve(400), 400)
        XCTAssertEqual(cursor.reserve(900), 600)
        XCTAssertEqual(cursor.reserve(10), 0)
        XCTAssertTrue(cursor.isComplete)
    }

    func testReserveNeverExceedsAReducedCapacity() {
        let cursor = ChunkWriteCursor(written: 700, capacity: 1000)
        cursor.capCapacity(toRemaining: 100)
        XCTAssertEqual(cursor.reserve(500), 100)
        XCTAssertEqual(cursor.written, 800)
        XCTAssertTrue(cursor.isComplete)
    }

    func testCapCapacityKeepsWrittenBytes() {
        let cursor = ChunkWriteCursor(written: 700, capacity: 1000)
        cursor.capCapacity(toRemaining: 100)
        XCTAssertEqual(cursor.capacity, 800)
        XCTAssertEqual(cursor.written, 700)
        XCTAssertEqual(cursor.remaining, 100)
    }

    func testCapCapacityNeverGrowsCapacity() {
        let cursor = ChunkWriteCursor(written: 700, capacity: 1000)
        cursor.capCapacity(toRemaining: 900)
        XCTAssertEqual(cursor.capacity, 1000)
    }
}
