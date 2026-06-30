//
//  GameSaveInputTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class GameSaveInputTests: XCTestCase {

    func testGameSaveInput_init() {
        let input = GameSetupUtil.GameSaveInput(
            gameName: "TestGame",
            selectedGameVersion: "1.20.1",
            selectedModLoader: "fabric",
            specifiedLoaderVersion: "0.14.0",
            pendingIconData: Data("icon".utf8)
        )

        XCTAssertEqual(input.gameName, "TestGame")
        XCTAssertEqual(input.selectedGameVersion, "1.20.1")
        XCTAssertEqual(input.selectedModLoader, "fabric")
        XCTAssertEqual(input.specifiedLoaderVersion, "0.14.0")
        XCTAssertNotNil(input.pendingIconData)
    }

    func testGameSaveInput_nilIconData() {
        let input = GameSetupUtil.GameSaveInput(
            gameName: "TestGame",
            selectedGameVersion: "1.20.1",
            selectedModLoader: "vanilla",
            specifiedLoaderVersion: "",
            pendingIconData: nil
        )
        XCTAssertNil(input.pendingIconData)
    }
}
