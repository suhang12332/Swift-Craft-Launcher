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
        XCTAssertEqual(first.count, 32)
    }

    func testGenerateOfflineUUID_emptyUsername_throws() {
        XCTAssertThrowsError(try PlayerUtils.generateOfflineUUID(for: "")) { error in
            let globalError = error as? GlobalError
            XCTAssertEqual(globalError?.i18nKey, "error.player.invalid_username_empty")
        }
    }

    func testAvatarName_validUUID_returnsName() throws {
        let uuid = try PlayerUtils.generateOfflineUUID(for: "Steve")
        XCTAssertNotNil(PlayerUtils.avatarName(for: uuid))
    }

    func testAvatarName_invalidUUID_returnsNil() {
        XCTAssertNil(PlayerUtils.avatarName(for: "not-a-valid-uuid"))
    }
}
