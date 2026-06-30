//
//  GameFormModeTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class GameFormModeTests: XCTestCase {

    func testIsImportMode_creation_returnsFalse() {
        let mode = GameFormMode.creation
        XCTAssertFalse(mode.isImportMode)
    }

    func testIsImportMode_modPackImport_returnsTrue() {
        let mode = GameFormMode.modPackImport(file: URL(fileURLWithPath: "/tmp/test.zip"), shouldProcess: true)
        XCTAssertTrue(mode.isImportMode)
    }

    func testIsImportMode_modPackImport_shouldProcessFalse_returnsTrue() {
        let mode = GameFormMode.modPackImport(file: URL(fileURLWithPath: "/tmp/test.zip"), shouldProcess: false)
        XCTAssertTrue(mode.isImportMode)
    }
}
