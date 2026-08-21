//
//  WorldNBTMapperTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import SwiftNBT
import XCTest

final class WorldNBTMapperTests: XCTestCase {
    func testReadBoolFlag_fromByte() {
        XCTAssertTrue(WorldNBTMapper.readBoolFlag(.byte(1)))
        XCTAssertFalse(WorldNBTMapper.readBoolFlag(.byte(0)))
    }

    func testReadBoolFlag_fromLong() {
        XCTAssertTrue(WorldNBTMapper.readBoolFlag(.long(-1)))
        XCTAssertFalse(WorldNBTMapper.readBoolFlag(.long(0)))
    }

    func testReadBoolFlag_nil_returnsFalse() {
        XCTAssertFalse(WorldNBTMapper.readBoolFlag(nil))
        XCTAssertFalse(WorldNBTMapper.readBoolFlag(.string("not a bool")))
    }

    func testMapDifficulty_peaceful() {
        let peaceful = WorldNBTMapper.mapDifficulty(0)
        let hard = WorldNBTMapper.mapDifficulty(3)
        XCTAssertNotEqual(peaceful, hard)
    }

    func testReadSeed_fromRandomSeed() {
        let dataTag: NBTCompound = ["RandomSeed": .long(999)]
        XCTAssertEqual(WorldNBTMapper.readSeed(from: dataTag, worldPath: nil), 999)
    }

    func testReadSeed_fromWorldGenSettings() {
        let dataTag: NBTCompound = [
            "WorldGenSettings": .compound(["seed": .long(42_424_242)]),
        ]
        XCTAssertEqual(WorldNBTMapper.readSeed(from: dataTag, worldPath: nil), 42_424_242)
    }

    func testReadSeed_fromLowercaseWorldGenSettings() {
        let dataTag: NBTCompound = [
            "worldGenSettings": .compound(["seed": .long(7)]),
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

    func testFlattenCompound_nested() {
        let compound: NBTCompound = [
            "a": .int(1),
            "b": .compound(["c": .string("x")]),
        ]
        let flat = WorldNBTMapper.flattenCompound(compound)
        XCTAssertEqual(flat["a"], "1")
        XCTAssertEqual(flat["b.c"], "x")
    }
}
