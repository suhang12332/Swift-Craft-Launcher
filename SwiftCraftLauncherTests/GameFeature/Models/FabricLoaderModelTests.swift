//
//  FabricLoaderModelTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class FabricLoaderModelTests: XCTestCase {
    func testFabricLoader_codable() throws {
        let json = """
        {
            "loader": {
                "version": "0.14.21"
            }
        }
        """
        let loader = try JSONDecoder().decode(FabricLoader.self, from: Data(json.utf8))

        XCTAssertEqual(loader.loader.version, "0.14.21")
    }

    func testFabricLoader_variousVersions() throws {
        let versions = ["0.14.0", "0.14.21", "0.15.0", "1.0.0"]
        for version in versions {
            let json = """
            {"loader": {"version": "\(version)"}}
            """
            let loader = try JSONDecoder().decode(FabricLoader.self, from: Data(json.utf8))
            XCTAssertEqual(loader.loader.version, version)
        }
    }

    func testFabricLoader_arrayCodable() throws {
        let json = """
        [
            {"loader": {"version": "0.14.0"}},
            {"loader": {"version": "0.14.21"}},
            {"loader": {"version": "0.15.0"}}
        ]
        """
        let loaders = try JSONDecoder().decode([FabricLoader].self, from: Data(json.utf8))

        XCTAssertEqual(loaders.count, 3)
        XCTAssertEqual(loaders[0].loader.version, "0.14.0")
        XCTAssertEqual(loaders[1].loader.version, "0.14.21")
        XCTAssertEqual(loaders[2].loader.version, "0.15.0")
    }

    func testFabricLoader_codable_roundTrip() throws {
        let original = FabricLoader(loader: FabricLoader.LoaderInfo(version: "0.14.21"))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FabricLoader.self, from: data)

        XCTAssertEqual(decoded.loader.version, original.loader.version)
    }
}
