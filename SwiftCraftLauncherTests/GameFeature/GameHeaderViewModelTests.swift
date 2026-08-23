//
//  GameHeaderViewModelTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

@MainActor
final class GameHeaderViewModelTests: XCTestCase {
    func testNameValidationRejectsEmptyAndUnchangedNames() {
        let viewModel = GameHeaderViewModel()

        XCTAssertFalse(viewModel.isNameValid(newName: "  ", currentName: "Current"))
        XCTAssertFalse(viewModel.isNameValid(newName: " Current ", currentName: "Current"))
    }

    func testNameValidationAcceptsUnusedName() {
        let viewModel = GameHeaderViewModel()
        let uniqueName = "scl-rename-test-\(UUID().uuidString)"

        XCTAssertTrue(viewModel.isNameValid(newName: uniqueName, currentName: "Current"))
    }
}
