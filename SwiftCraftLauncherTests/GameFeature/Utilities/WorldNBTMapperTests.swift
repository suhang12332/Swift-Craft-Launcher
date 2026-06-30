//
//  WorldNBTMapperTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class WorldNBTMapperTests: XCTestCase {
    func testReadInt64_fromInt() {
        XCTAssertEqual(WorldNBTMapper.readInt64(42), 42)
    }

    func testReadInt64_fromUInt8() {
        XCTAssertEqual(WorldNBTMapper.readInt64(UInt8(255)), 255)
    }

    func testReadInt64_nil() {
        XCTAssertNil(WorldNBTMapper.readInt64(nil))
        XCTAssertNil(WorldNBTMapper.readInt64("not-a-number"))
    }

    func testReadBoolFlag_fromBool() {
        XCTAssertTrue(WorldNBTMapper.readBoolFlag(true))
        XCTAssertFalse(WorldNBTMapper.readBoolFlag(false))
    }

    func testReadBoolFlag_fromInt() {
        XCTAssertTrue(WorldNBTMapper.readBoolFlag(1))
        XCTAssertFalse(WorldNBTMapper.readBoolFlag(0))
    }

    func testReadBoolFlag_nil_returnsFalse() {
        XCTAssertFalse(WorldNBTMapper.readBoolFlag(nil))
    }

    func testMapDifficulty_peaceful() {
        let peaceful = WorldNBTMapper.mapDifficulty(0)
        let hard = WorldNBTMapper.mapDifficulty(3)
        XCTAssertNotEqual(peaceful, hard)
    }

    func testReadSeed_fromRandomSeed() {
        let dataTag: [String: Any] = ["RandomSeed": Int64(999)]
        XCTAssertEqual(WorldNBTMapper.readSeed(from: dataTag, worldPath: nil), 999)
    }

    func testReadSeed_fromWorldGenSettings() {
        let dataTag: [String: Any] = [
            "WorldGenSettings": ["seed": Int64(42_424_242)],
        ]
        XCTAssertEqual(WorldNBTMapper.readSeed(from: dataTag, worldPath: nil), 42_424_242)
    }

    func testReadSeed_fromLowercaseWorldGenSettings() {
        let dataTag: [String: Any] = [
            "worldGenSettings": ["seed": Int64(7)],
        ]
        XCTAssertEqual(WorldNBTMapper.readSeed(from: dataTag, worldPath: nil), 7)
    }

    func testReadSeed_missing() {
        XCTAssertNil(WorldNBTMapper.readSeed(from: [:], worldPath: nil))
    }

    func testMapGameMode_survival() {
        let survival = WorldNBTMapper.mapGameMode(0)
        let creative = WorldNBTMapper.mapGameMode(1)

        XCTAssertFalse(survival.isEmpty)
        XCTAssertFalse(creative.isEmpty)
        XCTAssertNotEqual(survival, creative)
    }

    func testMapDifficultyString_hard() {
        let hard = WorldNBTMapper.mapDifficultyString("hard")
        let peaceful = WorldNBTMapper.mapDifficultyString("peaceful")

        XCTAssertFalse(hard.isEmpty)
        XCTAssertFalse(peaceful.isEmpty)
        XCTAssertNotEqual(hard, peaceful)
    }
}
