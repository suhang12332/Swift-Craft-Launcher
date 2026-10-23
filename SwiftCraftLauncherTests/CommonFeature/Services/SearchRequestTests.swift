//
//  SearchRequestTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class SearchRequestTests: XCTestCase {
    func testMakeURL_appendsQueryItems() throws {
        let url = try SearchRequestBuilder.makeURL(
            baseURL: URL.require("https://api.modrinth.com/v2/search"),
            queryItems: [
                URLQueryItem(name: "limit", value: "20"),
                URLQueryItem(name: "index", value: "relevance"),
            ],
            urlErrorMessage: "should not be used",
        )

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.queryItems?.count, 2)
        XCTAssertEqual(components?.queryItems?.first?.name, "limit")
        XCTAssertEqual(components?.queryItems?.first?.value, "20")
    }

    func testMakeURL_preservesBasePath() throws {
        let url = try SearchRequestBuilder.makeURL(
            baseURL: URL.require("https://api.curseforge.com/v1/mods/search"),
            queryItems: [URLQueryItem(name: "gameId", value: "432")],
            urlErrorMessage: "should not be used",
        )

        XCTAssertEqual(url.path, "/v1/mods/search")
    }

    func testJSONQueryItem_encodesStringArray() throws {
        let item = try SearchRequestBuilder.jsonQueryItem(
            name: "gameVersions",
            value: ["1.20.1", "1.21"],
            i18nKey: "error.validation.encode_game_versions_failed",
            contextLabel: "gameVersions",
        )

        XCTAssertEqual(item.name, "gameVersions")
        XCTAssertEqual(item.value, "[\"1.20.1\",\"1.21\"]")
    }

    func testJSONQueryItem_encodesNestedFacets() throws {
        let item = try SearchRequestBuilder.jsonQueryItem(
            name: "facets",
            value: [["project_type:mod"], ["versions:1.20.1"]],
            i18nKey: "error.validation.search_condition_encode_failed",
            contextLabel: "Modrinth search facets",
        )

        XCTAssertEqual(item.value, "[[\"project_type:mod\"],[\"versions:1.20.1\"]]")
    }

    func testPaginationLimits_matchProviderCaps() {
        XCTAssertEqual(SearchPagination.pageSize, 20)
        XCTAssertEqual(SearchPagination.modrinthMaxLimit, 100)
        XCTAssertEqual(SearchPagination.curseForgeMaxPageSize, 50)
    }
}
