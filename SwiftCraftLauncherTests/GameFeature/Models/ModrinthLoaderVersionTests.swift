//
//  ModrinthLoaderVersionTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ModrinthLoaderVersionTests: XCTestCase {
    func testLoaderInfo_codable() throws {
        let json = """
        {"id": "fabric", "url": "https://example.com", "stable": true}
        """
        let data = Data(json.utf8)
        let info = try JSONDecoder().decode(LoaderInfo.self, from: data)

        XCTAssertEqual(info.id, "fabric")
        XCTAssertEqual(info.url, "https://example.com")
        XCTAssertTrue(info.stable)
    }

    func testLoaderInfo_codable_unstable() throws {
        let json = """
        {"id": "quilt", "url": "https://example.com", "stable": false}
        """
        let data = Data(json.utf8)
        let info = try JSONDecoder().decode(LoaderInfo.self, from: data)

        XCTAssertEqual(info.id, "quilt")
        XCTAssertFalse(info.stable)
    }

    func testLoaderVersion_codable() throws {
        let json = """
        {
            "id": "0.14.21",
            "stable": true,
            "loaders": [
                {"id": "fabric", "url": "https://example.com", "stable": true},
                {"id": "quilt", "url": "https://example2.com", "stable": false}
            ]
        }
        """
        let data = Data(json.utf8)
        let version = try JSONDecoder().decode(LoaderVersion.self, from: data)

        XCTAssertEqual(version.id, "0.14.21")
        XCTAssertTrue(version.stable)
        XCTAssertEqual(version.loaders.count, 2)
        XCTAssertEqual(version.loaders[0].id, "fabric")
        XCTAssertEqual(version.loaders[1].id, "quilt")
        XCTAssertFalse(version.loaders[1].stable)
    }

    func testLoaderVersion_codable_emptyLoaders() throws {
        let json = """
        {
            "id": "1.0.0",
            "stable": false,
            "loaders": []
        }
        """
        let data = Data(json.utf8)
        let version = try JSONDecoder().decode(LoaderVersion.self, from: data)

        XCTAssertEqual(version.id, "1.0.0")
        XCTAssertFalse(version.stable)
        XCTAssertTrue(version.loaders.isEmpty)
    }

    func testModrinthLoaderVersion_codable() throws {
        let json = """
        {
            "gameVersions": [
                {
                    "id": "0.14.21",
                    "stable": true,
                    "loaders": [{"id": "fabric", "url": "https://example.com", "stable": true}]
                }
            ]
        }
        """
        let data = Data(json.utf8)
        let version = try JSONDecoder().decode(ModrinthLoaderVersion.self, from: data)

        XCTAssertEqual(version.gameVersions.count, 1)
        XCTAssertEqual(version.gameVersions[0].id, "0.14.21")
    }

    func testModrinthLoaderVersion_codable_multipleVersions() throws {
        let json = """
        {
            "gameVersions": [
                {"id": "0.14.21", "stable": true, "loaders": []},
                {"id": "0.15.0", "stable": false, "loaders": []}
            ]
        }
        """
        let data = Data(json.utf8)
        let version = try JSONDecoder().decode(ModrinthLoaderVersion.self, from: data)

        XCTAssertEqual(version.gameVersions.count, 2)
    }
}
