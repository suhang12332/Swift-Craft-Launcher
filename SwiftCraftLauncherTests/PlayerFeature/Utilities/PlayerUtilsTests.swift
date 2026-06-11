import XCTest
@testable import SwiftCraftLauncher

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

    func testAvatarName_withDashes() throws {
        let uuid = "0c6ecd5a-db74-3f56-a5b1-5b7b2a7a4a23"
        let name = PlayerUtils.avatarName(for: uuid)
        XCTAssertNotNil(name)
    }
}
