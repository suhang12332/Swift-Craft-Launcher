//
//  YggdrasilProfileListParserTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class YggdrasilProfileListParserTests: XCTestCase {

    func testParse_plainArrayFormat() throws {
        let json = """
        [
            {
                "id": "abc-123",
                "name": "TestPlayer",
                "properties": []
            }
        ]
        """
        let data = Data(json.utf8)
        let result = CommonYggdrasilProfileListParser.parse(data: data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.first?.id, "abc-123")
        XCTAssertEqual(result?.first?.name, "TestPlayer")
    }

    func testParse_wrappedDataFormat() throws {
        let json = """
        {
            "data": [
                {"id": "id-1", "name": "Player1", "properties": []},
                {"id": "id-2", "name": "Player2", "properties": []}
            ]
        }
        """
        let data = Data(json.utf8)
        let result = CommonYggdrasilProfileListParser.parse(data: data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 2)
        XCTAssertEqual(result?.first?.name, "Player1")
        XCTAssertEqual(result?.last?.name, "Player2")
    }

    func testParse_wrappedProfilesFormat() throws {
        let json = """
        {
            "profiles": [
                {"id": "id-p1", "name": "Profile1", "properties": []}
            ]
        }
        """
        let data = Data(json.utf8)
        let result = CommonYggdrasilProfileListParser.parse(data: data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.first?.name, "Profile1")
    }

    func testParse_emptyData_returnsNil() {
        let result = CommonYggdrasilProfileListParser.parse(data: Data())
        XCTAssertNil(result)
    }

    func testParse_invalidJSON_returnsNil() {
        let result = CommonYggdrasilProfileListParser.parse(data: Data("not json".utf8))
        XCTAssertNil(result)
    }

    func testParse_emptyArray_returnsNil() {
        let result = CommonYggdrasilProfileListParser.parse(data: Data("[]".utf8))
        XCTAssertNil(result)
    }

    func testParse_emptyWrappedData_returnsNil() {
        let json = """
        {"data": []}
        """
        let result = CommonYggdrasilProfileListParser.parse(data: Data(json.utf8))
        XCTAssertNil(result)
    }

    func testParse_withSkinProperties() throws {
        let texturesDict: [String: Any] = [
            "textures": [
                "SKIN": [
                    "url": "https://example.com/skin.png",
                    "metadata": ["model": "slim"],
                ],
            ],
        ]
        let texturesData = try JSONSerialization.data(withJSONObject: texturesDict)
        let texturesBase64 = texturesData.base64EncodedString()

        let json = """
        [
            {
                "id": "skin-test",
                "name": "SkinPlayer",
                "properties": [
                    {"name": "textures", "value": "\(texturesBase64)"}
                ]
            }
        ]
        """
        let data = Data(json.utf8)
        let result = CommonYggdrasilProfileListParser.parse(data: data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.first?.skins.count, 1)
        XCTAssertEqual(result?.first?.skins.first?.url, "https://example.com/skin.png")
        XCTAssertEqual(result?.first?.skins.first?.variant, "slim")
    }

    func testParse_withSkinAndCape() throws {
        let texturesDict: [String: Any] = [
            "textures": [
                "SKIN": ["url": "https://example.com/skin.png"],
                "CAPE": ["url": "https://example.com/cape.png"],
            ],
        ]
        let texturesData = try JSONSerialization.data(withJSONObject: texturesDict)
        let texturesBase64 = texturesData.base64EncodedString()

        let json = """
        [
            {
                "id": "both",
                "name": "BothPlayer",
                "properties": [
                    {"name": "textures", "value": "\(texturesBase64)"}
                ]
            }
        ]
        """
        let data = Data(json.utf8)
        let result = CommonYggdrasilProfileListParser.parse(data: data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.first?.skins.count, 1)
        XCTAssertEqual(result?.first?.capes?.count, 1)
        XCTAssertEqual(result?.first?.capes?.first?.url, "https://example.com/cape.png")
    }

    func testParse_noProperties_getsDefaultSkin() throws {
        let json = """
        [
            {
                "id": "no-props",
                "name": "DefaultSkinPlayer"
            }
        ]
        """
        let data = Data(json.utf8)
        let result = CommonYggdrasilProfileListParser.parse(data: data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.first?.skins.count, 1)
        XCTAssertEqual(result?.first?.skins.first?.url, "")
        XCTAssertEqual(result?.first?.skins.first?.variant, "classic")
        XCTAssertNil(result?.first?.capes)
    }

    func testParse_withSkinOnlyNoMetadata() throws {
        let texturesDict: [String: Any] = [
            "textures": [
                "SKIN": ["url": "https://example.com/skin.png"],
            ],
        ]
        let texturesData = try JSONSerialization.data(withJSONObject: texturesDict)
        let texturesBase64 = texturesData.base64EncodedString()

        let json = """
        [
            {
                "id": "no-meta",
                "name": "NoMetaPlayer",
                "properties": [
                    {"name": "textures", "value": "\(texturesBase64)"}
                ]
            }
        ]
        """
        let data = Data(json.utf8)
        let result = CommonYggdrasilProfileListParser.parse(data: data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.first?.skins.first?.variant, "classic")
    }

    func testBlessingSkinParse_withSkinAndCape() throws {
        let json = """
        [
            {
                "pid": 1,
                "uid": 100,
                "name": "BSPlayer",
                "tid_skin": 42,
                "tid_cape": 99
            }
        ]
        """
        let data = Data(json.utf8)
        let result = BlessingSkinProfileListParser.parse(data: data, baseURL: "https://example.com")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.first?.name, "BSPlayer")
        XCTAssertEqual(result?.first?.skins.first?.url, "https://example.com/raw/42")
        XCTAssertEqual(result?.first?.capes?.first?.url, "https://example.com/raw/99")
    }

    func testBlessingSkinParse_skinOnly() throws {
        let json = """
        [
            {"pid": 2, "name": "SkinOnly", "tid_skin": 55, "tid_cape": 0}
        ]
        """
        let data = Data(json.utf8)
        let result = BlessingSkinProfileListParser.parse(data: data, baseURL: "https://bs.example.com")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.first?.skins.first?.url, "https://bs.example.com/raw/55")
        XCTAssertNil(result?.first?.capes)
    }

    func testBlessingSkinParse_noSkin_getsDefault() throws {
        let json = """
        [
            {"pid": 3, "name": "NoSkin", "tid_skin": 0, "tid_cape": 0}
        ]
        """
        let data = Data(json.utf8)
        let result = BlessingSkinProfileListParser.parse(data: data, baseURL: "https://example.com")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.first?.skins.first?.url, "")
        XCTAssertEqual(result?.first?.skins.first?.variant, "classic")
    }

    func testBlessingSkinParse_emptyArray_returnsNil() {
        let result = BlessingSkinProfileListParser.parse(data: Data("[]".utf8), baseURL: "https://example.com")
        XCTAssertNil(result)
    }

    func testBlessingSkinParse_invalidJSON_returnsNil() {
        let result = BlessingSkinProfileListParser.parse(data: Data("invalid".utf8), baseURL: "https://example.com")
        XCTAssertNil(result)
    }

    func testBlessingSkinParse_generatesDeterministicUUID() throws {
        let json = """
        [
            {"name": "DeterministicPlayer", "tid_skin": 10}
        ]
        """
        let data = Data(json.utf8)
        let result1 = BlessingSkinProfileListParser.parse(data: data, baseURL: "https://example.com")
        let result2 = BlessingSkinProfileListParser.parse(data: data, baseURL: "https://example.com")

        XCTAssertEqual(result1?.first?.id, result2?.first?.id)
    }
}
