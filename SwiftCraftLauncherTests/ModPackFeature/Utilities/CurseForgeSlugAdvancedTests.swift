//
//  CurseForgeSlugAdvancedTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class CurseForgeSlugAdvancedTests: XCTestCase {

    func testToSlug_allAllowedSpecialChars() {
        let result = CurseForgeSlugHelper.toSlug("!@#$%^&*()")
        XCTAssertFalse(result.isEmpty)
    }

    func testToSlug_punctuation_onlyAllowed() {
        // Allowed: _!@$()`.+",-'  Others like #%^&*[]{}|:;<>?~ should be replaced
        let result = CurseForgeSlugHelper.toSlug("mod#name")
        XCTAssertFalse(result.contains("#"))
    }

    func testToSlug_chineseCharacters_onlyDashesThenEmpty() {
        let result = CurseForgeSlugHelper.toSlug("整合包")
        // Chinese chars replaced with dashes, trimmed, then too short -> empty
        XCTAssertTrue(result.isEmpty || result.allSatisfy { $0 == "-" || $0.isLetter || $0.isNumber })
    }

    func testToSlug_mixedContent() {
        let result = CurseForgeSlugHelper.toSlug("Mod Pack 1.0!")
        // Spaces become dashes, ! is allowed
        XCTAssertTrue(result.contains("mod"))
        XCTAssertTrue(result.contains("pack"))
    }

    func testToSlug_onlySpaces() {
        let result = CurseForgeSlugHelper.toSlug("   ")
        XCTAssertEqual(result, "")
    }

    func testToSlug_onlyDashes() {
        let result = CurseForgeSlugHelper.toSlug("---")
        XCTAssertEqual(result, "")
    }

    func testToSlug_leadingTrailingAllowedSpecialChars() {
        // ! @ are allowed chars, so they are preserved
        let result = CurseForgeSlugHelper.toSlug("!@hello@!")
        XCTAssertTrue(result.contains("hello"))
        XCTAssertTrue(result.hasPrefix("!"))
        XCTAssertTrue(result.hasSuffix("!"))
    }

    func testToSlug_exactly64Chars_mixed() {
        let input = String(repeating: "a", count: 60) + "!@#$"
        let result = CurseForgeSlugHelper.toSlug(input)
        XCTAssertEqual(result.count, 64)
    }

    func testToSlug_multipleConsecutiveSpaces() {
        let result = CurseForgeSlugHelper.toSlug("a    b")
        XCTAssertEqual(result, "a-b")
    }

    func testToSlug_multipleConsecutiveSpecialChars() {
        // ! is allowed, so consecutive ! are preserved
        let result = CurseForgeSlugHelper.toSlug("a!!!b")
        XCTAssertEqual(result, "a!!!b")
    }

    func testToSlug_multipleConsecutiveDisallowedChars() {
        // # is not allowed, so consecutive # collapse to single dash
        let result = CurseForgeSlugHelper.toSlug("a###b")
        XCTAssertEqual(result, "a-b")
    }

    func testIsValid_onlyAllowedChars() {
        XCTAssertTrue(CurseForgeSlugHelper.isValid("test_name"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("test-name"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("test.name"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("test!name"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("test@name"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("test$name"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("test(name)"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("test`name"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("test.name"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("test+name"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("test,name"))
        XCTAssertTrue(CurseForgeSlugHelper.isValid("test\"name"))
    }

    func testIsValid_disallowedChars() {
        XCTAssertFalse(CurseForgeSlugHelper.isValid("test name"))
        XCTAssertFalse(CurseForgeSlugHelper.isValid("test#name"))
        XCTAssertFalse(CurseForgeSlugHelper.isValid("test%name"))
        XCTAssertFalse(CurseForgeSlugHelper.isValid("test^name"))
        XCTAssertFalse(CurseForgeSlugHelper.isValid("test&name"))
        XCTAssertFalse(CurseForgeSlugHelper.isValid("test*name"))
        XCTAssertFalse(CurseForgeSlugHelper.isValid("test=name"))
        XCTAssertFalse(CurseForgeSlugHelper.isValid("test?name"))
        XCTAssertFalse(CurseForgeSlugHelper.isValid("test<name"))
        XCTAssertFalse(CurseForgeSlugHelper.isValid("test>name"))
        XCTAssertFalse(CurseForgeSlugHelper.isValid("test|name"))
        XCTAssertFalse(CurseForgeSlugHelper.isValid("test[name"))
        XCTAssertFalse(CurseForgeSlugHelper.isValid("test]name"))
        XCTAssertFalse(CurseForgeSlugHelper.isValid("test{name"))
        XCTAssertFalse(CurseForgeSlugHelper.isValid("test}name"))
    }

    func testIsValid_exactBoundaries() {
        XCTAssertTrue(CurseForgeSlugHelper.isValid(String(repeating: "a", count: 3)))
        XCTAssertTrue(CurseForgeSlugHelper.isValid(String(repeating: "a", count: 64)))
        XCTAssertFalse(CurseForgeSlugHelper.isValid(String(repeating: "a", count: 2)))
        XCTAssertFalse(CurseForgeSlugHelper.isValid(String(repeating: "a", count: 65)))
    }

    func testIsValid_toSlug_roundTrip() {
        let names = [
            "My Cool Mod",
            "mod_name.v2",
            "Test Pack 1.0",
            "整合包测试",
            "!@#$%",
            "a  b  c",
        ]

        for name in names {
            let slug = CurseForgeSlugHelper.toSlug(name)
            if !slug.isEmpty {
                XCTAssertTrue(
                    CurseForgeSlugHelper.isValid(slug),
                    "Slug '\(slug)' from '\(name)' should be valid"
                )
            }
        }
    }
}
