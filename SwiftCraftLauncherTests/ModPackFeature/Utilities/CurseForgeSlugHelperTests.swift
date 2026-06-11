import XCTest
@testable import SwiftCraftLauncher

final class CurseForgeSlugHelperTests: XCTestCase {
    func testToSlug_simpleName() {
        XCTAssertEqual(CurseForgeSlugHelper.toSlug("My Cool Mod"), "my-cool-mod")
    }

    func testToSlug_allowedSpecialCharacters() {
        XCTAssertEqual(CurseForgeSlugHelper.toSlug("mod_name.v2"), "mod_name.v2")
    }

    func testToSlug_tooShort_returnsEmpty() {
        XCTAssertEqual(CurseForgeSlugHelper.toSlug("ab"), "")
    }

    func testToSlug_empty_returnsEmpty() {
        XCTAssertEqual(CurseForgeSlugHelper.toSlug(""), "")
    }

    func testToSlug_truncatesTo64Characters() {
        let longName = String(repeating: "a", count: 80)
        XCTAssertEqual(CurseForgeSlugHelper.toSlug(longName).count, 64)
    }

    func testIsValid_validSlug() {
        XCTAssertTrue(CurseForgeSlugHelper.isValid("my-mod-pack"))
    }

    func testIsValid_tooShort() {
        XCTAssertFalse(CurseForgeSlugHelper.isValid("ab"))
    }

    func testIsValid_invalidCharacters() {
        XCTAssertFalse(CurseForgeSlugHelper.isValid("mod pack"))
    }
}
