//
//  CommonYggdrasilProfileListParserTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class CommonYggdrasilProfileListParserTests: XCTestCase {
    func testParse_arrayFormat() throws {
        let data = try Data(contentsOf: TestSupport.fixtureURL(
            subdirectory: "Fixtures/yggdrasil",
            name: "profile_list_array",
            extension: "json"
        ))

        let result = CommonYggdrasilProfileListParser.parse(data: data)

        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.first?.id, "uuid-1")
        XCTAssertEqual(result?.first?.name, "TestPlayer")
    }

    func testParse_wrappedDataFormat() throws {
        let data = try Data(contentsOf: TestSupport.fixtureURL(
            subdirectory: "Fixtures/yggdrasil",
            name: "profile_list_wrapped_data",
            extension: "json"
        ))

        let result = CommonYggdrasilProfileListParser.parse(data: data)

        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.first?.id, "uuid-2")
        XCTAssertEqual(result?.first?.name, "WrappedPlayer")
    }

    func testParse_wrappedProfilesFormat() throws {
        let data = try Data(contentsOf: TestSupport.fixtureURL(
            subdirectory: "Fixtures/yggdrasil",
            name: "profile_list_wrapped_profiles",
            extension: "json"
        ))

        let result = CommonYggdrasilProfileListParser.parse(data: data)

        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.first?.id, "uuid-3")
        XCTAssertEqual(result?.first?.name, "ProfilesPlayer")
    }

    func testParse_extractsSkinFromTextures() throws {
        let texturesJSON = """
        {"textures":{"SKIN":{"url":"https://example.com/skin.png","metadata":{"model":"slim"}}}}
        """
        let texturesValue = Data(texturesJSON.utf8).base64EncodedString()
        let json = """
        [{"id":"uuid-skin","name":"SkinPlayer","properties":[{"name":"textures","value":"\(texturesValue)"}]}]
        """

        let result = CommonYggdrasilProfileListParser.parse(data: Data(json.utf8))

        XCTAssertEqual(result?.first?.skins.first?.url, "https://example.com/skin.png")
        XCTAssertEqual(result?.first?.skins.first?.variant, "slim")
    }

    func testParse_extractsCapeFromTextures() throws {
        let texturesJSON = """
        {"textures":{"SKIN":{"url":"https://example.com/skin.png"},"CAPE":{"url":"https://example.com/cape.png"}}}
        """
        let texturesValue = Data(texturesJSON.utf8).base64EncodedString()
        let json = """
        [{"id":"uuid-cape","name":"CapePlayer","properties":[{"name":"textures","value":"\(texturesValue)"}]}]
        """

        let result = CommonYggdrasilProfileListParser.parse(data: Data(json.utf8))

        XCTAssertEqual(result?.first?.capes?.first?.url, "https://example.com/cape.png")
    }

    func testParse_invalidJSON_returnsNil() {
        XCTAssertNil(CommonYggdrasilProfileListParser.parse(data: Data("not-json".utf8)))
    }

    func testParse_emptyArray_returnsNil() {
        XCTAssertNil(CommonYggdrasilProfileListParser.parse(data: Data("[]".utf8)))
    }

    func testParse_emptyWrappedData_returnsNil() {
        XCTAssertNil(CommonYggdrasilProfileListParser.parse(data: Data("{\"data\":[]}".utf8)))
    }
}
