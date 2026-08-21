//
//  WorldNBTMapperExtendedTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import SwiftNBT
import XCTest

final class WorldNBTMapperExtendedTests: XCTestCase {
    func testReadInt64_supportedNumericTags() {
        XCTAssertEqual(WorldNBTMapper.readInt64(.byte(42)), 42)
        XCTAssertEqual(WorldNBTMapper.readInt64(.short(42)), 42)
        XCTAssertEqual(WorldNBTMapper.readInt64(.int(42)), 42)
        XCTAssertEqual(WorldNBTMapper.readInt64(.long(42)), 42)
    }

    func testReadInt64_unsupportedTags() {
        XCTAssertNil(WorldNBTMapper.readInt64(.string("not a number")))
        XCTAssertNil(WorldNBTMapper.readInt64(nil))
    }

    func testReadBoolFlag_numericTags() {
        XCTAssertTrue(WorldNBTMapper.readBoolFlag(.byte(1)))
        XCTAssertFalse(WorldNBTMapper.readBoolFlag(.byte(0)))
        XCTAssertTrue(WorldNBTMapper.readBoolFlag(.int(1)))
        XCTAssertFalse(WorldNBTMapper.readBoolFlag(.int(0)))
    }

    func testReadBoolFlag_unsupportedTags() {
        XCTAssertFalse(WorldNBTMapper.readBoolFlag(.string("not a bool")))
        XCTAssertFalse(WorldNBTMapper.readBoolFlag(nil))
    }

    func testMapGameMode_allValues() {
        for value in 0 ... 3 {
            XCTAssertFalse(WorldNBTMapper.mapGameMode(value).isEmpty)
        }
        XCTAssertFalse(WorldNBTMapper.mapGameMode(99).isEmpty)
    }

    func testMapDifficulty_allValues() {
        for value in 0 ... 3 {
            XCTAssertFalse(WorldNBTMapper.mapDifficulty(value).isEmpty)
        }
        XCTAssertFalse(WorldNBTMapper.mapDifficulty(99).isEmpty)
    }

    func testMapDifficultyString_allValues() {
        for value in ["peaceful", "easy", "normal", "hard", "HARD", "unknown"] {
            XCTAssertFalse(WorldNBTMapper.mapDifficultyString(value).isEmpty)
        }
    }

    func testReadSeed_allSupportedLocations() {
        XCTAssertEqual(
            WorldNBTMapper.readSeed(from: ["RandomSeed": .long(12345)], worldPath: nil),
            12345,
        )
        XCTAssertEqual(
            WorldNBTMapper.readSeed(
                from: ["WorldGenSettings": .compound(["seed": .long(67890)])],
                worldPath: nil,
            ),
            67890,
        )
        XCTAssertEqual(
            WorldNBTMapper.readSeed(
                from: ["worldGenSettings": .compound(["seed": .long(11111)])],
                worldPath: nil,
            ),
            11111,
        )
        XCTAssertNil(WorldNBTMapper.readSeed(from: ["other": .string("value")], worldPath: nil))
    }
}
