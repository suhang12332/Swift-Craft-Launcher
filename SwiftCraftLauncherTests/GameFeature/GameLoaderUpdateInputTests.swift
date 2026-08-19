//
//  GameLoaderUpdateInputTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class GameLoaderUpdateInputTests: XCTestCase {
    func testGameLoaderUpdateInput_init() {
        let input = GameSetupUtil.GameLoaderUpdateInput(
            selectedModLoader: "fabric",
            specifiedLoaderVersion: "0.16.0",
        )

        XCTAssertEqual(input.selectedModLoader, "fabric")
        XCTAssertEqual(input.specifiedLoaderVersion, "0.16.0")
    }

    func testGameLoaderUpdateInput_vanilla() {
        let input = GameSetupUtil.GameLoaderUpdateInput(
            selectedModLoader: GameLoader.vanilla.displayName,
            specifiedLoaderVersion: GameLoader.vanilla.displayName,
        )

        XCTAssertEqual(input.selectedModLoader, "vanilla")
        XCTAssertEqual(input.specifiedLoaderVersion, "vanilla")
    }
}
