//
//  NBTParserTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class NBTParserTests: XCTestCase {
    func testParse_emptyData_throws() {
        XCTAssertThrowsError(try NBTParser(data: Data()).parse()) { error in
            let globalError = error as? GlobalError
            XCTAssertEqual(globalError?.i18nKey, "error.filesystem.nbt_empty_data")
        }
    }

    func testParse_invalidRoot_throws() {
        // Root tag must be Compound (0x0A); 0x01 is Byte.
        var invalid = Data([0x01, 0x00, 0x00])
        invalid.append(contentsOf: [UInt8(0)])

        XCTAssertThrowsError(try NBTParser(data: invalid).parse()) { error in
            let globalError = error as? GlobalError
            XCTAssertEqual(globalError?.i18nKey, "error.filesystem.nbt_invalid_root")
        }
    }

    func testEncodeDecode_roundTrip_uncompressed() throws {
        let original: [String: Any] = [
            "Data": ["RandomSeed": Int64(12_345)],
            "DataVersion": Int32(3_465),
        ]

        let encoded = try NBTParser.encode(original, compress: false)
        let parsed = try NBTParser(data: encoded).parse()

        XCTAssertEqual(parsed["DataVersion"] as? Int32, 3_465)
        let dataTag = parsed["Data"] as? [String: Any]
        XCTAssertEqual(dataTag?["RandomSeed"] as? Int64, 12_345)
    }

    func testEncodeDecode_roundTrip_compressed() throws {
        let original: [String: Any] = [
            "Data": ["RandomSeed": Int64(99_999)],
            "DataVersion": Int32(2_970),
        ]

        let encoded = try NBTParser.encode(original, compress: true)
        XCTAssertEqual(encoded.prefix(2), Data([0x1F, 0x8B]))

        let parsed = try NBTParser(data: encoded).parse()
        let dataTag = parsed["Data"] as? [String: Any]
        XCTAssertEqual(dataTag?["RandomSeed"] as? Int64, 99_999)
    }

    func testRoundTrip_serversDatStructure() throws {
        let original: [String: Any] = [
            "servers": [
                [
                    "name": "Test Server",
                    "ip": "localhost",
                    "hidden": Int8(0),
                    "acceptTextures": Int8(1),
                ] as [String: Any],
            ],
        ]

        let encoded = try NBTParser.encode(original, compress: true)
        let parsed = try NBTParser(data: encoded).parse()
        let servers = parsed["servers"] as? [[String: Any]]

        XCTAssertEqual(servers?.count, 1)
        XCTAssertEqual(servers?.first?["name"] as? String, "Test Server")
        XCTAssertEqual(servers?.first?["ip"] as? String, "localhost")
    }

    func testRoundTrip_levelDatMinimalFields() throws {
        let original: [String: Any] = [
            "Data": [
                "RandomSeed": Int64(-123_456_789),
                "LevelName": "Test World",
            ],
            "DataVersion": Int32(3_456),
        ]

        let encoded = try NBTParser.encode(original, compress: false)
        let parsed = try NBTParser(data: encoded).parse()

        XCTAssertEqual(parsed["DataVersion"] as? Int32, 3_456)
        let dataTag = parsed["Data"] as? [String: Any]
        XCTAssertEqual(dataTag?["LevelName"] as? String, "Test World")
        XCTAssertEqual(dataTag?["RandomSeed"] as? Int64, -123_456_789)
    }

    func testParse_gzipPrefixedData() throws {
        let original: [String: Any] = ["hello": "world"]
        let compressed = try NBTParser.encode(original, compress: true)
        let parsed = try NBTParser(data: compressed).parse()

        XCTAssertEqual(parsed["hello"] as? String, "world")
    }

    func testEncode_emptyCompound() throws {
        let encoded = try NBTParser.encode([:], compress: false)
        let parsed = try NBTParser(data: encoded).parse()

        XCTAssertTrue(parsed.isEmpty)
    }

    func testRoundTrip_nestedListAndScalars() throws {
        let original: [String: Any] = [
            "count": Int32(3),
            "tags": ["alpha", "beta"],
            "enabled": true,
        ]

        let encoded = try NBTParser.encode(original, compress: false)
        let parsed = try NBTParser(data: encoded).parse()

        XCTAssertEqual(parsed["count"] as? Int32, 3)
        let tags = parsed["tags"] as? [Any]
        XCTAssertEqual(tags?.count, 2)
        XCTAssertEqual(tags?[0] as? String, "alpha")
        XCTAssertEqual(tags?[1] as? String, "beta")
        XCTAssertEqual(parsed["enabled"] as? Int8, 1)
    }

    func testRoundTrip_nestedCompound() throws {
        let original: [String: Any] = [
            "outer": [
                "inner": "value",
            ] as [String: Any],
        ]

        let encoded = try NBTParser.encode(original, compress: false)
        let parsed = try NBTParser(data: encoded).parse()
        let outer = parsed["outer"] as? [String: Any]

        XCTAssertEqual(outer?["inner"] as? String, "value")
    }
}
