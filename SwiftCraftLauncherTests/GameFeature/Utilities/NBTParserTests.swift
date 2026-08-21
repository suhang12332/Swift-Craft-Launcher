//
//  NBTParserTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftNBT
import XCTest

final class NBTParserTests: XCTestCase {
    func testDecode_emptyData_throws() {
        XCTAssertThrowsError(try NBTDecoder().decode(Data())) { error in
            XCTAssertEqual(error as? NBTError, .emptyData)
        }
    }

    func testDecode_invalidRoot_throws() {
        let invalid = Data([0x01, 0x00, 0x00, 0x00])

        XCTAssertThrowsError(try NBTDecoder().decode(invalid)) { error in
            XCTAssertEqual(error as? NBTError, .invalidRootType(1))
        }
    }

    func testEncodeDecode_roundTrip_uncompressed() throws {
        let document = NBTDocument(root: [
            "Data": .compound(["RandomSeed": .long(12_345)]),
            "DataVersion": .int(3465),
        ])

        let encoded = try NBTEncoder().encode(document, compression: .none)
        let parsed = try NBTDecoder().decode(encoded, compression: .none)

        XCTAssertEqual(parsed.root["DataVersion"]?.int64Value, 3465)
        XCTAssertEqual(parsed.root["Data"]?.compoundValue?["RandomSeed"]?.int64Value, 12_345)
    }

    func testEncodeDecode_roundTrip_compressed() throws {
        let document = NBTDocument(root: [
            "Data": .compound(["RandomSeed": .long(99_999)]),
            "DataVersion": .int(2970),
        ])

        let encoded = try NBTEncoder().encode(document)
        XCTAssertEqual(encoded.prefix(2), Data([0x1F, 0x8B]))

        let parsed = try NBTDecoder().decode(encoded)
        XCTAssertEqual(parsed.root["Data"]?.compoundValue?["RandomSeed"]?.int64Value, 99_999)
    }

    func testRoundTrip_serversDatStructure() throws {
        let document = NBTDocument(root: [
            "servers": .list([
                .compound([
                    "name": .string("Test Server"),
                    "ip": .string("localhost"),
                    "hidden": .byte(0),
                    "acceptTextures": .byte(1),
                ]),
            ]),
        ])

        let encoded = try NBTEncoder().encode(document)
        let parsed = try NBTDecoder().decode(encoded)
        guard case let .list(servers)? = parsed.root["servers"],
              case let .compound(server)? = servers.first else {
            return XCTFail("servers list was not decoded")
        }

        XCTAssertEqual(server["name"]?.stringValue, "Test Server")
        XCTAssertEqual(server["ip"]?.stringValue, "localhost")
    }

    func testRoundTrip_levelDatMinimalFields() throws {
        let document = NBTDocument(root: [
            "Data": .compound([
                "RandomSeed": .long(-123_456_789),
                "LevelName": .string("Test World"),
            ]),
            "DataVersion": .int(3456),
        ])

        let encoded = try NBTEncoder().encode(document, compression: .none)
        let parsed = try NBTDecoder().decode(encoded, compression: .none)
        let data = parsed.root["Data"]?.compoundValue

        XCTAssertEqual(parsed.root["DataVersion"]?.int64Value, 3456)
        XCTAssertEqual(data?["LevelName"]?.stringValue, "Test World")
        XCTAssertEqual(data?["RandomSeed"]?.int64Value, -123_456_789)
    }

    func testEncodeDecode_gzipPrefixedData() throws {
        let document = NBTDocument(root: ["hello": .string("world")])
        let compressed = try NBTEncoder().encode(document)
        let parsed = try NBTDecoder().decode(compressed)

        XCTAssertEqual(parsed.root["hello"]?.stringValue, "world")
    }

    func testEncodeDecode_emptyCompound() throws {
        let document = NBTDocument(root: [:])
        let encoded = try NBTEncoder().encode(document, compression: .none)
        let parsed = try NBTDecoder().decode(encoded, compression: .none)

        XCTAssertTrue(parsed.root.isEmpty)
    }

    func testRoundTrip_nestedListAndScalars() throws {
        let document = NBTDocument(root: [
            "count": .int(3),
            "tags": .list([.string("alpha"), .string("beta")]),
            "enabled": .byte(1),
        ])

        let encoded = try NBTEncoder().encode(document, compression: .none)
        let parsed = try NBTDecoder().decode(encoded, compression: .none)

        XCTAssertEqual(parsed.root["count"]?.int64Value, 3)
        if case let .list(tags)? = parsed.root["tags"] {
            XCTAssertEqual(tags.count, 2)
        } else {
            XCTFail("tags list was not decoded")
        }
        XCTAssertEqual(parsed.root["enabled"]?.boolValue, true)
    }

    func testRoundTrip_nestedCompound() throws {
        let document = NBTDocument(root: [
            "outer": .compound(["inner": .string("value")]),
        ])

        let encoded = try NBTEncoder().encode(document, compression: .none)
        let parsed = try NBTDecoder().decode(encoded, compression: .none)

        XCTAssertEqual(parsed.root["outer"]?.compoundValue?["inner"]?.stringValue, "value")
    }
}
