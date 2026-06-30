//
//  GameLoaderTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class GameLoaderTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(GameLoader.vanilla.rawValue, "vanilla")
        XCTAssertEqual(GameLoader.fabric.rawValue, "fabric")
        XCTAssertEqual(GameLoader.forge.rawValue, "forge")
        XCTAssertEqual(GameLoader.neoforge.rawValue, "neoforge")
        XCTAssertEqual(GameLoader.quilt.rawValue, "quilt")
    }

    func testAllCases_count() {
        XCTAssertEqual(GameLoader.allCases.count, 5)
    }

    func testAllCases_containsAll() {
        XCTAssertTrue(GameLoader.allCases.contains(.vanilla))
        XCTAssertTrue(GameLoader.allCases.contains(.fabric))
        XCTAssertTrue(GameLoader.allCases.contains(.forge))
        XCTAssertTrue(GameLoader.allCases.contains(.neoforge))
        XCTAssertTrue(GameLoader.allCases.contains(.quilt))
    }

    func testId_equalsRawValue() {
        XCTAssertEqual(GameLoader.vanilla.id, "vanilla")
        XCTAssertEqual(GameLoader.fabric.id, "fabric")
        XCTAssertEqual(GameLoader.forge.id, "forge")
        XCTAssertEqual(GameLoader.neoforge.id, "neoforge")
        XCTAssertEqual(GameLoader.quilt.id, "quilt")
    }

    func testDisplayName_vanilla() {
        XCTAssertEqual(GameLoader.vanilla.displayName, "vanilla")
    }

    func testDisplayName_fabric() {
        XCTAssertEqual(GameLoader.fabric.displayName, "fabric")
    }

    func testDisplayName_forge() {
        XCTAssertEqual(GameLoader.forge.displayName, "forge")
    }

    func testDisplayName_neoforge() {
        XCTAssertEqual(GameLoader.neoforge.displayName, "neoforge")
    }

    func testDisplayName_quilt() {
        XCTAssertEqual(GameLoader.quilt.displayName, "quilt")
    }

    func testCodable_roundTrip() throws {
        let enc = JSONEncoder()
        let dec = JSONDecoder()

        for loader in GameLoader.allCases {
            let data = try enc.encode(loader)
            let decoded = try dec.decode(GameLoader.self, from: data)
            XCTAssertEqual(decoded, loader)
        }
    }

    func testCodable_fromRawString() throws {
        let json = "\"fabric\""
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(GameLoader.self, from: data)
        XCTAssertEqual(decoded, .fabric)
    }
}
