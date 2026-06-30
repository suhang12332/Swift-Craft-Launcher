//
//  GameNameGeneratorTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class GameNameGeneratorExtendedTests: XCTestCase {

    func testGenerateModPackName_withTitle_noTimestamp() {
        let result = GameNameGenerator.generateModPackName(
            projectTitle: "MyModPack",
            gameVersion: "1.20.1",
            includeTimestamp: false
        )
        XCTAssertEqual(result, "MyModPack-1.20.1")
    }

    func testGenerateModPackName_nilTitle_noTimestamp() {
        let result = GameNameGenerator.generateModPackName(
            projectTitle: nil,
            gameVersion: "1.20.1",
            includeTimestamp: false
        )
        XCTAssertEqual(result, "ModPack-1.20.1")
    }

    func testGenerateModPackName_withTimestamp() {
        let result = GameNameGenerator.generateModPackName(
            projectTitle: "Test",
            gameVersion: "1.20.1",
            includeTimestamp: true
        )
        XCTAssertTrue(result.hasPrefix("Test-1.20.1-"))
        XCTAssertTrue(result.count > "Test-1.20.1-".count)
    }

    func testGenerateImportName_noTimestamp() {
        let result = GameNameGenerator.generateImportName(
            modPackName: "AllTheMods",
            modPackVersion: "9.1",
            includeTimestamp: false
        )
        XCTAssertEqual(result, "AllTheMods-9.1")
    }

    func testGenerateImportName_withTimestamp() {
        let result = GameNameGenerator.generateImportName(
            modPackName: "Test",
            modPackVersion: "1.0",
            includeTimestamp: true
        )
        XCTAssertTrue(result.hasPrefix("Test-1.0-"))
    }

    func testGenerateGameName_vanilla_noTimestamp() {
        let result = GameNameGenerator.generateGameName(
            gameVersion: "1.20.1",
            loaderVersion: "",
            modLoader: "vanilla",
            includeTimestamp: false
        )
        XCTAssertEqual(result, "1.20.1-vanilla")
    }

    func testGenerateGameName_fabric_noTimestamp() {
        let result = GameNameGenerator.generateGameName(
            gameVersion: "1.20.1",
            loaderVersion: "0.14.0",
            modLoader: "fabric",
            includeTimestamp: false
        )
        XCTAssertEqual(result, "1.20.1-fabric-0.14.0")
    }

    func testGenerateGameName_forge_noTimestamp() {
        let result = GameNameGenerator.generateGameName(
            gameVersion: "1.20.1",
            loaderVersion: "47.2.0",
            modLoader: "forge",
            includeTimestamp: false
        )
        XCTAssertEqual(result, "1.20.1-forge-47.2.0")
    }

    func testGenerateGameName_withTimestamp() {
        let result = GameNameGenerator.generateGameName(
            gameVersion: "1.20.1",
            loaderVersion: "0.14.0",
            modLoader: "fabric",
            includeTimestamp: true
        )
        XCTAssertTrue(result.hasPrefix("1.20.1-fabric-0.14.0-"))
    }

    func testGenerateGameName_vanillaCaseInsensitive() {
        let result = GameNameGenerator.generateGameName(
            gameVersion: "1.20.1",
            loaderVersion: "",
            modLoader: "Vanilla",
            includeTimestamp: false
        )
        XCTAssertEqual(result, "1.20.1-vanilla")
    }
}
