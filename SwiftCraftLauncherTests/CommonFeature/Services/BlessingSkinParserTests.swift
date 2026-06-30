//
//  BlessingSkinParserTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class BlessingSkinParserTests: XCTestCase {
    func testParse_emptyArray_returnsNil() {
        let data = Data("[]".utf8)
        let result = BlessingSkinProfileListParser.parse(data: data, baseURL: "https://example.com")
        XCTAssertNil(result)
    }

    func testParse_invalidJSON_returnsNil() {
        let data = Data("not json".utf8)
        let result = BlessingSkinProfileListParser.parse(data: data, baseURL: "https://example.com")
        XCTAssertNil(result)
    }

    func testParse_emptyData_returnsNil() {
        let data = Data()
        let result = BlessingSkinProfileListParser.parse(data: data, baseURL: "https://example.com")
        XCTAssertNil(result)
    }

    func testParse_withSkinOnly() {
        let json = """
        [{"name": "Steve", "tid_skin": 42, "tid_cape": null}]
        """
        let data = Data(json.utf8)
        let result = BlessingSkinProfileListParser.parse(data: data, baseURL: "https://bs.example.com")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.first?.name, "Steve")
        XCTAssertEqual(result?.first?.skins.count, 1)
        XCTAssertEqual(result?.first?.skins.first?.url, "https://bs.example.com/raw/42")
        XCTAssertEqual(result?.first?.skins.first?.variant, "classic")
        XCTAssertNil(result?.first?.capes)
    }

    func testParse_withSkinAndCape() {
        let json = """
        [{"name": "Alex", "tid_skin": 10, "tid_cape": 20}]
        """
        let data = Data(json.utf8)
        let result = BlessingSkinProfileListParser.parse(data: data, baseURL: "https://bs.example.com")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.first?.skins.count, 1)
        XCTAssertEqual(result?.first?.capes?.count, 1)
        XCTAssertEqual(result?.first?.capes?.first?.url, "https://bs.example.com/raw/20")
    }

    func testParse_noSkin_getsDefault() {
        let json = """
        [{"name": "Noor", "tid_skin": null, "tid_cape": null}]
        """
        let data = Data(json.utf8)
        let result = BlessingSkinProfileListParser.parse(data: data, baseURL: "https://bs.example.com")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.first?.skins.count, 1)
        XCTAssertEqual(result?.first?.skins.first?.url, "")
    }

    func testParse_generatesDeterministicUUID() {
        let json = """
        [{"name": "TestPlayer", "tid_skin": 1}]
        """
        let data = Data(json.utf8)
        let result = BlessingSkinProfileListParser.parse(data: data, baseURL: "https://bs.example.com")

        XCTAssertNotNil(result)
        let id = result?.first?.id
        XCTAssertNotNil(id)
        XCTAssertEqual(id?.count, 32)
    }

    func testParse_multiplePlayers() {
        let json = """
        [
            {"name": "Steve", "tid_skin": 1},
            {"name": "Alex", "tid_skin": 2},
            {"name": "Noor", "tid_skin": null, "tid_cape": 5}
        ]
        """
        let data = Data(json.utf8)
        let result = BlessingSkinProfileListParser.parse(data: data, baseURL: "https://bs.example.com")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 3)
    }

    func testParser_id_isMUA() {
        let parser = CommonBlessingSkinStyleProfileListParser(baseURL: "https://bs.example.com")
        XCTAssertEqual(parser.id, .mua)
    }

    func testParser_parse_delegatesToStatic() async {
        let parser = CommonBlessingSkinStyleProfileListParser(baseURL: "https://bs.example.com")
        let json = """
        [{"name": "Steve", "tid_skin": 1}]
        """
        let data = Data(json.utf8)
        let result = await parser.parse(data: data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.first?.name, "Steve")
    }

    func testParser_parse_invalidData_returnsNil() async {
        let parser = CommonBlessingSkinStyleProfileListParser(baseURL: "https://bs.example.com")
        let data = Data("invalid".utf8)
        let result = await parser.parse(data: data)

        XCTAssertNil(result)
    }
}
