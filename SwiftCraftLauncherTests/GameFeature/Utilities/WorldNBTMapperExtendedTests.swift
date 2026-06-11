import XCTest
@testable import SwiftCraftLauncher

final class WorldNBTMapperExtendedTests: XCTestCase {

    // MARK: - readInt64

    func testReadInt64_int64() {
        XCTAssertEqual(WorldNBTMapper.readInt64(Int64(42)), 42)
    }

    func testReadInt64_int() {
        XCTAssertEqual(WorldNBTMapper.readInt64(Int(42)), 42)
    }

    func testReadInt64_int32() {
        XCTAssertEqual(WorldNBTMapper.readInt64(Int32(42)), 42)
    }

    func testReadInt64_int16() {
        XCTAssertEqual(WorldNBTMapper.readInt64(Int16(42)), 42)
    }

    func testReadInt64_int8() {
        XCTAssertEqual(WorldNBTMapper.readInt64(Int8(42)), 42)
    }

    func testReadInt64_uint64() {
        XCTAssertEqual(WorldNBTMapper.readInt64(UInt64(42)), 42)
    }

    func testReadInt64_uint32() {
        XCTAssertEqual(WorldNBTMapper.readInt64(UInt32(42)), 42)
    }

    func testReadInt64_uint16() {
        XCTAssertEqual(WorldNBTMapper.readInt64(UInt16(42)), 42)
    }

    func testReadInt64_uint8() {
        XCTAssertEqual(WorldNBTMapper.readInt64(UInt8(42)), 42)
    }

    func testReadInt64_nil() {
        XCTAssertNil(WorldNBTMapper.readInt64(nil))
    }

    func testReadInt64_string() {
        XCTAssertNil(WorldNBTMapper.readInt64("not a number"))
    }

    // MARK: - readBoolFlag

    func testReadBoolFlag_boolTrue() {
        XCTAssertTrue(WorldNBTMapper.readBoolFlag(true))
    }

    func testReadBoolFlag_boolFalse() {
        XCTAssertFalse(WorldNBTMapper.readBoolFlag(false))
    }

    func testReadBoolFlag_intNonZero() {
        XCTAssertTrue(WorldNBTMapper.readBoolFlag(1))
    }

    func testReadBoolFlag_intZero() {
        XCTAssertFalse(WorldNBTMapper.readBoolFlag(0))
    }

    func testReadBoolFlag_nil() {
        XCTAssertFalse(WorldNBTMapper.readBoolFlag(nil))
    }

    func testReadBoolFlag_string() {
        XCTAssertFalse(WorldNBTMapper.readBoolFlag("not a bool"))
    }

    // MARK: - mapGameMode

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

    // MARK: - mapDifficulty

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

    // MARK: - mapDifficultyString

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

    // MARK: - readSeed

    func testReadSeed_randomSeed() {
        let dataTag: [String: Any] = ["RandomSeed": Int64(12345)]
        let seed = WorldNBTMapper.readSeed(from: dataTag, worldPath: nil)
        XCTAssertEqual(seed, 12345)
    }

    func testReadSeed_worldGenSettings() {
        let dataTag: [String: Any] = [
            "WorldGenSettings": ["seed": Int64(67890)]
        ]
        let seed = WorldNBTMapper.readSeed(from: dataTag, worldPath: nil)
        XCTAssertEqual(seed, 67890)
    }

    func testReadSeed_worldGenSettings_lowercase() {
        let dataTag: [String: Any] = [
            "worldGenSettings": ["seed": Int64(11111)]
        ]
        let seed = WorldNBTMapper.readSeed(from: dataTag, worldPath: nil)
        XCTAssertEqual(seed, 11111)
    }

    func testReadSeed_noSeed() {
        let dataTag: [String: Any] = ["other": "value"]
        let seed = WorldNBTMapper.readSeed(from: dataTag, worldPath: nil)
        XCTAssertNil(seed)
    }
}
