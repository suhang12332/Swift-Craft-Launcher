//
//  QuiltLoaderModelTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class QuiltLoaderModelTests: XCTestCase {

    func testQuiltLoaderResponse_codable() throws {
        let json = """
        {
            "loader": {
                "version": "0.26.0"
            }
        }
        """
        let response = try JSONDecoder().decode(QuiltLoaderResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.loader.version, "0.26.0")
    }

    func testQuiltLoaderResponse_arrayCodable() throws {
        let json = """
        [
            {"loader": {"version": "0.26.0"}},
            {"loader": {"version": "0.27.0"}}
        ]
        """
        let responses = try JSONDecoder().decode([QuiltLoaderResponse].self, from: Data(json.utf8))

        XCTAssertEqual(responses.count, 2)
        XCTAssertEqual(responses[0].loader.version, "0.26.0")
        XCTAssertEqual(responses[1].loader.version, "0.27.0")
    }

    func testQuiltLoaderResponse_betaVersionParsing() throws {
        let json = """
        {"loader": {"version": "0.28.0-beta.1"}}
        """
        let response = try JSONDecoder().decode(QuiltLoaderResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.loader.version, "0.28.0-beta.1")
        XCTAssertTrue(response.loader.version.lowercased().contains("beta"))
    }

    func testQuiltLoaderResponse_preVersionParsing() throws {
        let json = """
        {"loader": {"version": "0.29.0-pre1"}}
        """
        let response = try JSONDecoder().decode(QuiltLoaderResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.loader.version, "0.29.0-pre1")
        XCTAssertTrue(response.loader.version.lowercased().contains("pre"))
    }

    func testQuiltLoaderResponse_codable_roundTrip() throws {
        let original = QuiltLoaderResponse(loader: QuiltLoaderResponse.Loader(version: "0.26.0"))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(QuiltLoaderResponse.self, from: data)

        XCTAssertEqual(decoded.loader.version, original.loader.version)
    }

    func testFiltering_betaVersionsExcluded() {
        let responses = [
            QuiltLoaderResponse(loader: .init(version: "0.26.0")),
            QuiltLoaderResponse(loader: .init(version: "0.28.0-beta.1")),
            QuiltLoaderResponse(loader: .init(version: "0.27.0")),
        ]

        let filtered = responses.filter {
            !$0.loader.version.lowercased().contains("beta") &&
            !$0.loader.version.lowercased().contains("pre")
        }

        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered[0].loader.version, "0.26.0")
        XCTAssertEqual(filtered[1].loader.version, "0.27.0")
    }

    func testFiltering_preVersionsExcluded() {
        let responses = [
            QuiltLoaderResponse(loader: .init(version: "0.26.0")),
            QuiltLoaderResponse(loader: .init(version: "0.29.0-pre1")),
            QuiltLoaderResponse(loader: .init(version: "0.27.0")),
        ]

        let filtered = responses.filter {
            !$0.loader.version.lowercased().contains("beta") &&
            !$0.loader.version.lowercased().contains("pre")
        }

        XCTAssertEqual(filtered.count, 2)
    }

    func testFiltering_allStableVersions() {
        let responses = [
            QuiltLoaderResponse(loader: .init(version: "0.26.0")),
            QuiltLoaderResponse(loader: .init(version: "0.27.0")),
        ]

        let filtered = responses.filter {
            !$0.loader.version.lowercased().contains("beta") &&
            !$0.loader.version.lowercased().contains("pre")
        }

        XCTAssertEqual(filtered.count, 2)
    }

    func testFiltering_allBetaVersions() {
        let responses = [
            QuiltLoaderResponse(loader: .init(version: "0.28.0-beta.1")),
            QuiltLoaderResponse(loader: .init(version: "0.29.0-beta.2")),
        ]

        let filtered = responses.filter {
            !$0.loader.version.lowercased().contains("beta") &&
            !$0.loader.version.lowercased().contains("pre")
        }

        XCTAssertEqual(filtered.count, 0)
    }

    func testFiltering_emptyArray() {
        let responses: [QuiltLoaderResponse] = []

        let filtered = responses.filter {
            !$0.loader.version.lowercased().contains("beta") &&
            !$0.loader.version.lowercased().contains("pre")
        }

        XCTAssertTrue(filtered.isEmpty)
    }

    func testFiltering_caseInsensitive() {
        let responses = [
            QuiltLoaderResponse(loader: .init(version: "0.28.0-BETA.1")),
            QuiltLoaderResponse(loader: .init(version: "0.29.0-Pre1")),
        ]

        let filtered = responses.filter {
            !$0.loader.version.lowercased().contains("beta") &&
            !$0.loader.version.lowercased().contains("pre")
        }

        XCTAssertEqual(filtered.count, 0)
    }
}
