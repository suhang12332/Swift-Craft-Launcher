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
        GameNameValidator()
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

    func testIsFormValid_whitespaceOnlyName_returnsFalse() {
        let validator = makeValidator()
        validator.gameName = "   \n"
        validator.isGameNameDuplicate = false
        XCTAssertFalse(validator.isFormValid)
    }

    func testIsFormValid_pathTraversal_returnsFalse() {
        let validator = makeValidator()
        validator.gameName = "../OtherGame"
        validator.isGameNameDuplicate = false
        XCTAssertFalse(validator.isFormValid)
    }

    func testIsFormValid_absolutePath_returnsFalse() {
        let validator = makeValidator()
        validator.gameName = "/tmp/EvilGame"
        validator.isGameNameDuplicate = false
        XCTAssertFalse(validator.isFormValid)
    }

    func testIsFormValid_relativePathSegment_returnsFalse() {
        let validator = makeValidator()
        validator.gameName = "instances/OtherGame"
        validator.isGameNameDuplicate = false
        XCTAssertFalse(validator.isFormValid)
    }

    func testIsFormValid_dotNames_returnsFalse() {
        let validator = makeValidator()
        validator.isGameNameDuplicate = false

        for name in [".", "..", " .. ", ".minecraft", "Game.", " .Game. "] {
            validator.gameName = name
            XCTAssertFalse(validator.isFormValid, "expected \(name) to be rejected")
        }
    }

    func testIsFormValid_controlCharacters_returnsFalse() {
        let validator = makeValidator()
        validator.gameName = "My\u{0000}Game"
        validator.isGameNameDuplicate = false
        XCTAssertFalse(validator.isFormValid)
    }

    func testIsFormValid_nameWithSpaces_returnsTrue() {
        let validator = makeValidator()
        validator.gameName = "My Test Game"
        validator.isGameNameDuplicate = false
        XCTAssertTrue(validator.isFormValid)
    }

    func testIsFormValid_doubleDotAnywhere_returnsFalse() {
        let validator = makeValidator()
        validator.isGameNameDuplicate = false

        for name in ["..Game", "Game..", "Game..1", "a..b", ".."] {
            validator.gameName = name
            XCTAssertFalse(validator.isFormValid, "expected \(name) to be rejected")
        }
    }

    func testIsFormValid_singleDotsAllowed_returnsTrue() {
        let validator = makeValidator()
        validator.gameName = "Minecraft 1.20.1"
        validator.isGameNameDuplicate = false
        XCTAssertTrue(validator.isFormValid)
    }

    func testIsValidName_rejectsPathLikeInput() {
        XCTAssertFalse(GameNameValidator.isValidName(""))
        XCTAssertFalse(GameNameValidator.isValidName("  "))
        XCTAssertFalse(GameNameValidator.isValidName("."))
        XCTAssertFalse(GameNameValidator.isValidName(".."))
        XCTAssertFalse(GameNameValidator.isValidName("../"))
        XCTAssertFalse(GameNameValidator.isValidName("a/b"))
        XCTAssertFalse(GameNameValidator.isValidName("C:\\Games"))
        XCTAssertFalse(GameNameValidator.isValidName("Game\u{000A}Two"))
    }

    func testIsValidName_rejectsUnsafeTokensAtEveryPosition() {
        for position in ["../Game", "Ga../me", "Game../"] {
            XCTAssertFalse(GameNameValidator.isValidName(position), "expected \(position) to be rejected")
        }

        for position in ["/Game", "Ga/me", "Game/"] {
            XCTAssertFalse(GameNameValidator.isValidName(position), "expected \(position) to be rejected")
        }

        for position in ["\\Game", "Ga\\me", "Game\\"] {
            XCTAssertFalse(GameNameValidator.isValidName(position), "expected \(position) to be rejected")
        }
    }

    func testIsValidName_rejectsDotAtStartOrEnd() {
        for position in [".Game", " .Game", ".Game."] {
            XCTAssertFalse(GameNameValidator.isValidName(position), "expected \(position) to be rejected")
        }

        for position in ["Game.", "Game. ", "Game.."] {
            XCTAssertFalse(GameNameValidator.isValidName(position), "expected \(position) to be rejected")
        }
    }

    func testIsValidName_acceptsOrdinaryNames() {
        XCTAssertTrue(GameNameValidator.isValidName("TestGame"))
        XCTAssertTrue(GameNameValidator.isValidName(" TestGame "))
        XCTAssertTrue(GameNameValidator.isValidName("我的世界 1.20"))
        XCTAssertTrue(GameNameValidator.isValidName("My_Game-1.20.1"))
        XCTAssertTrue(GameNameValidator.isValidName("Minecraft. Fabric"))
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
}
