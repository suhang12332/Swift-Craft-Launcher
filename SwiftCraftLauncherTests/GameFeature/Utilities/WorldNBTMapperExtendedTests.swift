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
    func testReadBoolFlag_byteTrue() {
        XCTAssertTrue(WorldNBTMapper.readBoolFlag(.byte(1)))
    }

    func testReadBoolFlag_byteFalse() {
        XCTAssertFalse(WorldNBTMapper.readBoolFlag(.byte(0)))
    }

    func testReadBoolFlag_intNonZero() {
        XCTAssertTrue(WorldNBTMapper.readBoolFlag(.int(1)))
    }

    func testReadBoolFlag_intZero() {
        XCTAssertFalse(WorldNBTMapper.readBoolFlag(.int(0)))
    }

    func testReadBoolFlag_longNegative() {
        XCTAssertTrue(WorldNBTMapper.readBoolFlag(.long(-1)))
    }

    func testReadBoolFlag_nil() {
        XCTAssertFalse(WorldNBTMapper.readBoolFlag(nil))
    }

    func testReadBoolFlag_string() {
        XCTAssertFalse(WorldNBTMapper.readBoolFlag(.string("not a bool")))
    }

    func testMapGameMode_survival() {
        let result = WorldNBTMapper.mapGameMode(0)
        XCTAssertFalse(result.isEmpty)
    }

    func testMapGameMode_creative() {
        let result = WorldNBTMapper.mapGameMode(1)
        XCTAssertFalse(result.isEmpty)
    }

    func testMapGameMode_adventure() {
        let result = WorldNBTMapper.mapGameMode(2)
        XCTAssertFalse(result.isEmpty)
    }

    func testMapGameMode_spectator() {
        let result = WorldNBTMapper.mapGameMode(3)
        XCTAssertFalse(result.isEmpty)
    }

    func testMapGameMode_unknown() {
        let result = WorldNBTMapper.mapGameMode(99)
        XCTAssertFalse(result.isEmpty)
    }

    func testMapDifficulty_peaceful() {
        let result = WorldNBTMapper.mapDifficulty(0)
        XCTAssertFalse(result.isEmpty)
    }

    func testMapDifficulty_easy() {
        let result = WorldNBTMapper.mapDifficulty(1)
        XCTAssertFalse(result.isEmpty)
    }

    func testMapDifficulty_normal() {
        let result = WorldNBTMapper.mapDifficulty(2)
        XCTAssertFalse(result.isEmpty)
    }

    func testMapDifficulty_hard() {
        let result = WorldNBTMapper.mapDifficulty(3)
        XCTAssertFalse(result.isEmpty)
    }

    func testMapDifficulty_unknown() {
        let result = WorldNBTMapper.mapDifficulty(99)
        XCTAssertFalse(result.isEmpty)
    }

    func testMapDifficultyString_peaceful() {
        let result = WorldNBTMapper.mapDifficultyString("peaceful")
        XCTAssertFalse(result.isEmpty)
    }

    func testMapDifficultyString_easy() {
        let result = WorldNBTMapper.mapDifficultyString("easy")
        XCTAssertFalse(result.isEmpty)
    }

    func testMapDifficultyString_normal() {
        let result = WorldNBTMapper.mapDifficultyString("normal")
        XCTAssertFalse(result.isEmpty)
    }

    func testMapDifficultyString_hard() {
        let result = WorldNBTMapper.mapDifficultyString("hard")
        XCTAssertFalse(result.isEmpty)
    }

    func testMapDifficultyString_caseInsensitive() {
        let result = WorldNBTMapper.mapDifficultyString("HARD")
        XCTAssertFalse(result.isEmpty)
    }

    func testMapDifficultyString_unknown() {
        let result = WorldNBTMapper.mapDifficultyString("unknown")
        XCTAssertFalse(result.isEmpty)
    }

    func testReadSeed_randomSeed() {
        let dataTag: NBTCompound = ["RandomSeed": .long(12345)]
        let seed = WorldNBTMapper.readSeed(from: dataTag, worldPath: nil)
        XCTAssertEqual(seed, 12345)
    }

    func testReadSeed_worldGenSettings() {
        let dataTag: NBTCompound = [
            "WorldGenSettings": .compound(["seed": .long(67890)]),
        ]
        let seed = WorldNBTMapper.readSeed(from: dataTag, worldPath: nil)
        XCTAssertEqual(seed, 67890)
    }

    func testReadSeed_worldGenSettings_lowercase() {
        let dataTag: NBTCompound = [
            "worldGenSettings": .compound(["seed": .long(11111)]),
        ]
        let seed = WorldNBTMapper.readSeed(from: dataTag, worldPath: nil)
        XCTAssertEqual(seed, 11111)
    }

    func testReadSeed_intValue() {
        let dataTag: NBTCompound = ["RandomSeed": .int(42)]
        let seed = WorldNBTMapper.readSeed(from: dataTag, worldPath: nil)
        XCTAssertEqual(seed, 42)
    }

    func testReadSeed_noSeed() {
        let dataTag: NBTCompound = ["other": .string("value")]
        let seed = WorldNBTMapper.readSeed(from: dataTag, worldPath: nil)
        XCTAssertNil(seed)
    }
}
