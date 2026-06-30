//
//  MinecraftServerInfoExtendedTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class MinecraftServerInfoExtendedTests: XCTestCase {

    func testDescription_plainText_textOnly() {
        let desc = MinecraftServerInfo.Description(text: "Hello World", extra: nil)
        XCTAssertEqual(desc.plainText, "Hello World")
    }

    func testDescription_plainText_nilText() {
        let desc = MinecraftServerInfo.Description(text: nil, extra: nil)
        XCTAssertEqual(desc.plainText, "")
    }

    func testDescription_plainText_stripsFormatCodes() {
        let desc = MinecraftServerInfo.Description(text: "§aGreen§c Red", extra: nil)
        XCTAssertEqual(desc.plainText, "Green Red")
    }

    func testDescription_plainText_stripsMultipleFormatCodes() {
        let desc = MinecraftServerInfo.Description(text: "§lBold§r Normal", extra: nil)
        XCTAssertEqual(desc.plainText, "Bold Normal")
    }

    func testDescription_plainText_stripsFormatCodeAtEnd() {
        let desc = MinecraftServerInfo.Description(text: "Hello§a", extra: nil)
        XCTAssertEqual(desc.plainText, "Hello")
    }

    func testDescription_plainText_extraElements() {
        let extra = [
            MinecraftServerInfo.Description.DescriptionElement.string("Hello "),
            MinecraftServerInfo.Description.DescriptionElement.string("World"),
        ]
        let desc = MinecraftServerInfo.Description(text: nil, extra: extra)
        XCTAssertEqual(desc.plainText, "Hello World")
    }

    func testDescription_plainText_nestedObject() {
        let inner = MinecraftServerInfo.Description(text: "Inner", extra: nil)
        let extra = [
            MinecraftServerInfo.Description.DescriptionElement.object(inner)
        ]
        let desc = MinecraftServerInfo.Description(text: "Outer ", extra: extra)
        XCTAssertEqual(desc.plainText, "Outer Inner")
    }

    func testDescription_plainText_emptyExtra() {
        let desc = MinecraftServerInfo.Description(text: "Text", extra: [])
        XCTAssertEqual(desc.plainText, "Text")
    }

    func testDescription_plainText_mixedStringAndObject() {
        let obj = MinecraftServerInfo.Description(text: "Obj", extra: nil)
        let extra: [MinecraftServerInfo.Description.DescriptionElement] = [
            .string("A "),
            .object(obj),
            .string(" B"),
        ]
        let desc = MinecraftServerInfo.Description(text: nil, extra: extra)
        XCTAssertEqual(desc.plainText, "A Obj B")
    }

    func testDescriptionElement_stringCodable() throws {
        let element = MinecraftServerInfo.Description.DescriptionElement.string("test")
        let data = try JSONEncoder().encode(element)
        let decoded = try JSONDecoder().decode(MinecraftServerInfo.Description.DescriptionElement.self, from: data)

        if case .string(let str) = decoded {
            XCTAssertEqual(str, "test")
        } else {
            XCTFail("Expected string element")
        }
    }

    func testDescriptionElement_objectCodable() throws {
        let inner = MinecraftServerInfo.Description(text: "inner", extra: nil)
        let element = MinecraftServerInfo.Description.DescriptionElement.object(inner)
        let data = try JSONEncoder().encode(element)
        let decoded = try JSONDecoder().decode(MinecraftServerInfo.Description.DescriptionElement.self, from: data)

        if case .object(let desc) = decoded {
            XCTAssertEqual(desc.text, "inner")
        } else {
            XCTFail("Expected object element")
        }
    }

    func testDescriptionElement_stringPlainText() {
        let element = MinecraftServerInfo.Description.DescriptionElement.string("hello")
        XCTAssertEqual(element.plainText, "hello")
    }

    func testDescriptionElement_objectPlainText() {
        let inner = MinecraftServerInfo.Description(text: "world", extra: nil)
        let element = MinecraftServerInfo.Description.DescriptionElement.object(inner)
        XCTAssertEqual(element.plainText, "world")
    }

    func testMinecraftServerInfo_codable_minimal() throws {
        let json = """
        {
            "description": {"text": "A Server"},
            "version": {"name": "1.20.1", "protocol": 763},
            "players": {"max": 20, "online": 5, "sample": []}
        }
        """
        let data = Data(json.utf8)
        let info = try JSONDecoder().decode(MinecraftServerInfo.self, from: data)

        XCTAssertEqual(info.description.text, "A Server")
        XCTAssertEqual(info.version?.name, "1.20.1")
        XCTAssertEqual(info.version?.protocol, 763)
        XCTAssertEqual(info.players?.max, 20)
        XCTAssertEqual(info.players?.online, 5)
    }

    func testMinecraftServerInfo_codable_noVersion() throws {
        let json = """
        {
            "description": {"text": "Server"}
        }
        """
        let data = Data(json.utf8)
        let info = try JSONDecoder().decode(MinecraftServerInfo.self, from: data)

        XCTAssertNil(info.version)
        XCTAssertNil(info.players)
    }

    func testMinecraftServerInfo_players_sample() throws {
        let json = """
        {
            "description": {"text": "Server"},
            "players": {
                "max": 100,
                "online": 10,
                "sample": [
                    {"name": "Steve", "id": "abc123"},
                    {"name": "Alex", "id": null}
                ]
            }
        }
        """
        let data = Data(json.utf8)
        let info = try JSONDecoder().decode(MinecraftServerInfo.self, from: data)

        XCTAssertEqual(info.players?.sample?.count, 2)
        XCTAssertEqual(info.players?.sample?[0].name, "Steve")
        XCTAssertEqual(info.players?.sample?[0].id, "abc123")
        XCTAssertNil(info.players?.sample?[1].id)
    }

    func testMinecraftServerInfo_modInfo() throws {
        let json = """
        {
            "description": {"text": "Modded Server"},
            "modinfo": {
                "type": "forge",
                "modList": [
                    {"modid": "minecraft", "version": "1.20.1"},
                    {"modid": "fabric-api", "version": "0.90.0"}
                ]
            }
        }
        """
        let data = Data(json.utf8)
        let info = try JSONDecoder().decode(MinecraftServerInfo.self, from: data)

        XCTAssertEqual(info.modinfo?.type, "forge")
        XCTAssertEqual(info.modinfo?.modList?.count, 2)
        XCTAssertEqual(info.modinfo?.modList?[0].modid, "minecraft")
    }

    func testMinecraftServerInfo_codable_roundTrip() throws {
        let original = MinecraftServerInfo(
            version: MinecraftServerInfo.Version(name: "1.21", protocol: 769),
            players: MinecraftServerInfo.Players(max: 50, online: 12, sample: nil),
            description: MinecraftServerInfo.Description(text: "Test", extra: nil),
            favicon: "data:image/png;base64,abc",
            modinfo: nil
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MinecraftServerInfo.self, from: data)

        XCTAssertEqual(decoded.version?.name, "1.21")
        XCTAssertEqual(decoded.players?.max, 50)
        XCTAssertEqual(decoded.description.text, "Test")
        XCTAssertEqual(decoded.favicon, "data:image/png;base64,abc")
    }

    func testMinecraftServerInfo_description_extraCodable() throws {
        let json = """
        {
            "description": {
                "text": "Hello ",
                "extra": [
                    {"text": "World"},
                    {"text": "!"}
                ]
            }
        }
        """
        let data = Data(json.utf8)
        let info = try JSONDecoder().decode(MinecraftServerInfo.self, from: data)

        XCTAssertEqual(info.description.extra?.count, 2)
    }

    func testMinecraftServerInfo_description_objectExtra() throws {
        let json = """
        {
            "description": {
                "extra": [
                    {"text": "Nested "},
                    {"text": "Inner", "extra": [{"text": "Deep"}]}
                ]
            }
        }
        """
        let data = Data(json.utf8)
        let info = try JSONDecoder().decode(MinecraftServerInfo.self, from: data)

        XCTAssertEqual(info.description.extra?.count, 2)
        if case .string(let str) = info.description.extra?[0] {
            XCTAssertEqual(str, "Nested ")
        }
    }
}
