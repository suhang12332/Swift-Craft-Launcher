//
//  PlayerUtilsTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class PlayerUtilsTests: XCTestCase {
    func testGenerateOfflineUUID_steve_produces32CharHex() throws {
        let uuid = try PlayerUtils.generateOfflineUUID(for: "Steve")
        XCTAssertEqual(uuid.count, 32)
        XCTAssertNil(uuid.range(of: "[^0-9a-f]", options: .regularExpression))
    }

    func testGenerateOfflineUUID_sameUsername_sameUUID() throws {
        let first = try PlayerUtils.generateOfflineUUID(for: "TestPlayer")
        let second = try PlayerUtils.generateOfflineUUID(for: "TestPlayer")
        XCTAssertEqual(first, second)
    }

    func testGenerateOfflineUUID_emptyUsername_throws() {
        XCTAssertThrowsError(try PlayerUtils.generateOfflineUUID(for: "")) { error in
            let globalError = error as? GlobalError
            XCTAssertEqual(globalError?.i18nKey, "error.player.invalid_username_empty")
        }
    }

    func testGenerateOfflineUUID_differentUsers_differentUUIDs() throws {
        let uuid1 = try PlayerUtils.generateOfflineUUID(for: "Player1")
        let uuid2 = try PlayerUtils.generateOfflineUUID(for: "Player2")
        XCTAssertNotEqual(uuid1, uuid2)
    }

    func testGenerateOfflineUUID_jeb() throws {
        let uuid = try PlayerUtils.generateOfflineUUID(for: "jeb_")
        XCTAssertEqual(uuid.count, 32)
    }

    func testAvatarName_validUUID_returnsName() throws {
        let uuid = try PlayerUtils.generateOfflineUUID(for: "Steve")
        XCTAssertNotNil(PlayerUtils.avatarName(for: uuid))
    }

    func testAvatarName_invalidUUID_returnsNil() {
        XCTAssertNil(PlayerUtils.avatarName(for: "not-a-valid-uuid"))
    }

    func testAvatarName_deterministic() throws {
        let uuid = try PlayerUtils.generateOfflineUUID(for: "TestPlayer")
        let name1 = PlayerUtils.avatarName(for: uuid)
        let name2 = PlayerUtils.avatarName(for: uuid)
        XCTAssertEqual(name1, name2)
    }

    func testAvatarName_shortUUID_returnsNil() {
        XCTAssertNil(PlayerUtils.avatarName(for: "abc123"))
    }

    func testAvatarName_withDashes() {
        let uuid = "0c6ecd5a-db74-3f56-a5b1-5b7b2a7a4a23"
        let name = PlayerUtils.avatarName(for: uuid)
        XCTAssertNotNil(name)
    }

    func testIsValidOfflineName_lettersDigitsUnderscore_returnsTrue() {
        XCTAssertTrue(PlayerUtils.isValidOfflineName("Steve_123"))
        XCTAssertTrue(PlayerUtils.isValidOfflineName("abc"))
        XCTAssertTrue(PlayerUtils.isValidOfflineName("a_1"))
        XCTAssertTrue(PlayerUtils.isValidOfflineName("0123456789"))
        XCTAssertTrue(PlayerUtils.isValidOfflineName("AZaz_09"))
    }

    func testIsValidOfflineNameLength_boundaries() {
        XCTAssertFalse(PlayerUtils.isValidOfflineNameLength(""))
        XCTAssertFalse(PlayerUtils.isValidOfflineNameLength("ab"))
        XCTAssertTrue(PlayerUtils.isValidOfflineNameLength("abc"))
        XCTAssertTrue(PlayerUtils.isValidOfflineNameLength(String(repeating: "a", count: 16)))
        XCTAssertFalse(PlayerUtils.isValidOfflineNameLength(String(repeating: "a", count: 17)))
    }

    func testIsValidOfflineName_tooShort_returnsFalse() {
        XCTAssertFalse(PlayerUtils.isValidOfflineName("ab"))
        XCTAssertFalse(PlayerUtils.isValidOfflineName("A1"))
    }

    func testIsValidOfflineName_tooLong_returnsFalse() {
        XCTAssertFalse(PlayerUtils.isValidOfflineName(String(repeating: "a", count: 17)))
    }

    func testIsValidOfflineName_empty_returnsFalse() {
        XCTAssertFalse(PlayerUtils.isValidOfflineName(""))
    }

    func testIsValidOfflineName_chinese_returnsFalse() {
        XCTAssertFalse(PlayerUtils.isValidOfflineName("史蒂夫"))
    }

    func testIsValidOfflineName_space_returnsFalse() {
        XCTAssertFalse(PlayerUtils.isValidOfflineName("Steve 1"))
        XCTAssertFalse(PlayerUtils.isValidOfflineName(" Steve"))
        XCTAssertFalse(PlayerUtils.isValidOfflineName("Steve "))
    }

    func testIsValidOfflineName_specialCharacters_returnsFalse() {
        XCTAssertFalse(PlayerUtils.isValidOfflineName("Steve!"))
        XCTAssertFalse(PlayerUtils.isValidOfflineName("steve-1"))
        XCTAssertFalse(PlayerUtils.isValidOfflineName("steve.1"))
        XCTAssertFalse(PlayerUtils.isValidOfflineName("steve@example"))
        XCTAssertFalse(PlayerUtils.isValidOfflineName("steve\n"))
    }

    func testIsValidOfflineName_fullWidthLetters_returnsFalse() {
        XCTAssertFalse(PlayerUtils.isValidOfflineName("Ｓｔｅｖｅ"))
    }

    func testIsValidOfflineName_accentedLetters_returnsFalse() {
        XCTAssertFalse(PlayerUtils.isValidOfflineName("Stevé"))
    }
}
