//
//  YggdrasilProfileListParserTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class YggdrasilProfileListParserTests: XCTestCase {
    func testParse_plainArrayFormat() {
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

    func testParse_wrappedDataFormat() {
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

    func testParse_wrappedProfilesFormat() {
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

    func testParse_noProperties_getsDefaultSkin() {
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
}
