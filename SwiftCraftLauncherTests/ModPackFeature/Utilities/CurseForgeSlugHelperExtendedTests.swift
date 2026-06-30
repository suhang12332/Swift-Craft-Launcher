//
//  CurseForgeSlugHelperExtendedTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class CurseForgeSlugHelperExtendedTests: XCTestCase {

    func testToSlug_singleChar_returnsEmpty() {
        XCTAssertEqual(CurseForgeSlugHelper.toSlug("a"), "")
    }

    func testToSlug_twoChars_returnsEmpty() {
        XCTAssertEqual(CurseForgeSlugHelper.toSlug("ab"), "")
    }

    func testToSlug_exactlyThreeChars() {
        XCTAssertEqual(CurseForgeSlugHelper.toSlug("abc"), "abc")
    }

    func testToSlug_exactly64Chars() {
        let slug = String(repeating: "a", count: 64)
        XCTAssertEqual(CurseForgeSlugHelper.toSlug(slug), slug)
    }

    func testToSlug_65Chars_truncates() {
        let input = String(repeating: "a", count: 65)
        XCTAssertEqual(CurseForgeSlugHelper.toSlug(input).count, 64)
    }

    func testToSlug_consecutiveSpecialChars_singleDash() {
        XCTAssertEqual(CurseForgeSlugHelper.toSlug("a  b"), "a-b")
    }

    func testToSlug_leadingTrailingSpaces_trimmed() {
        XCTAssertEqual(CurseForgeSlugHelper.toSlug("  hello  "), "hello")
    }

    func testToSlug_onlySpecialChars() {
        let result = CurseForgeSlugHelper.toSlug("!@#$")
        XCTAssertFalse(result.isEmpty)
    }

    func testToSlug_allowedChars_preserved() {
        XCTAssertEqual(CurseForgeSlugHelper.toSlug("mod_name.v2!"), "mod_name.v2!")
    }

    func testToSlug_chineseChars_notEmpty() {
        let result = CurseForgeSlugHelper.toSlug("整合包测试")
        XCTAssertFalse(result.isEmpty)
    }

    func testToSlug_uppercase_lowercased() {
        XCTAssertEqual(CurseForgeSlugHelper.toSlug("MyMod"), "mymod")
    }

    func testIsValid_exactly3Chars() {
        XCTAssertTrue(CurseForgeSlugHelper.isValid("abc"))
    }

    func testIsValid_exactly64Chars() {
        XCTAssertTrue(CurseForgeSlugHelper.isValid(String(repeating: "a", count: 64)))
    }

    func testIsValid_65Chars() {
        XCTAssertFalse(CurseForgeSlugHelper.isValid(String(repeating: "a", count: 65)))
    }

    func testIsValid_2Chars() {
        XCTAssertFalse(CurseForgeSlugHelper.isValid("ab"))
    }

    func testIsValid_empty() {
        XCTAssertFalse(CurseForgeSlugHelper.isValid(""))
    }

    func testIsValid_withAllowedSpecialChars() {
        XCTAssertTrue(CurseForgeSlugHelper.isValid("mod_name"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("mod-name"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("mod.name"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("mod!name"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("mod@name"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("mod$name"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("mod(name)"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("mod+name"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("mod,name"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("mod\"name"))
    }

    func testIsValid_spaceInvalid() {
        XCTAssertFalse(CurseForgeSlugHelper.isValid("mod name"))
    }

    func testIsValid_tabInvalid() {
        XCTAssertFalse(CurseForgeSlugHelper.isValid("mod\tname"))
    }
}
