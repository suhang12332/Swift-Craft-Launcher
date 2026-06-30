//
//  GameNameValidatorTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

@MainActor
final class GameNameValidatorTests: XCTestCase {
    private func makeValidator() -> GameNameValidator {
        GameNameValidator(gameSetupService: GameSetupUtil())
    }

    func testIsFormValid_emptyName_returnsFalse() {
        let validator = makeValidator()
        validator.gameName = ""
        validator.isGameNameDuplicate = false
        XCTAssertFalse(validator.isFormValid)
    }

    func testIsFormValid_nonEmptyNameNotDuplicate_returnsTrue() {
        let validator = makeValidator()
        validator.gameName = "TestGame"
        validator.isGameNameDuplicate = false
        XCTAssertTrue(validator.isFormValid)
    }

    func testIsFormValid_duplicateName_returnsFalse() {
        let validator = makeValidator()
        validator.gameName = "TestGame"
        validator.isGameNameDuplicate = true
        XCTAssertFalse(validator.isFormValid)
    }

    func testIsFormValid_emptyNameDuplicate_returnsFalse() {
        let validator = makeValidator()
        validator.gameName = ""
        validator.isGameNameDuplicate = true
        XCTAssertFalse(validator.isFormValid)
    }

    func testSetDefaultName_emptyName_setsName() {
        let validator = makeValidator()
        validator.gameName = ""
        validator.setDefaultName("MyGame")
        XCTAssertEqual(validator.gameName, "MyGame")
    }

    func testSetDefaultName_nonEmptyName_doesNotOverwrite() {
        let validator = makeValidator()
        validator.gameName = "ExistingGame"
        validator.setDefaultName("NewGame")
        XCTAssertEqual(validator.gameName, "ExistingGame")
    }

    func testSetDefaultName_emptyString_setsEmptyName() {
        let validator = makeValidator()
        validator.gameName = ""
        validator.setDefaultName("")
        XCTAssertEqual(validator.gameName, "")
    }

    func testReset_clearsNameAndDuplicate() {
        let validator = makeValidator()
        validator.gameName = "TestGame"
        validator.isGameNameDuplicate = true
        validator.reset()
        XCTAssertEqual(validator.gameName, "")
        XCTAssertFalse(validator.isGameNameDuplicate)
    }

    func testReset_fromEmptyState_succeeds() {
        let validator = makeValidator()
        validator.reset()
        XCTAssertEqual(validator.gameName, "")
        XCTAssertFalse(validator.isGameNameDuplicate)
    }

    func testValidateGameName_emptyName_setsDuplicateFalse() async {
        let validator = makeValidator()
        validator.gameName = ""
        validator.isGameNameDuplicate = true
        await validator.validateGameName()
        XCTAssertFalse(validator.isGameNameDuplicate)
    }
}
