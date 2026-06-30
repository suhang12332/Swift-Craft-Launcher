//
//  JavaDetailsFormattingTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class JavaDetailsFormattingTests: XCTestCase {

    func testDescription_normalInput() {
        let result = JavaDetailsFormatting.description(
            javaExecutablePath: "/usr/bin/java",
            versionOutput: "openjdk 17.0.2"
        )
        XCTAssertTrue(result.contains("/usr/bin/java"))
        XCTAssertTrue(result.contains("openjdk 17.0.2"))
    }

    func testDescription_emptyPath() {
        let result = JavaDetailsFormatting.description(
            javaExecutablePath: "",
            versionOutput: "openjdk 17.0.2"
        )
        XCTAssertEqual(result, "openjdk 17.0.2")
    }

    func testDescription_emptyVersion() {
        let result = JavaDetailsFormatting.description(
            javaExecutablePath: "/usr/bin/java",
            versionOutput: ""
        )
        XCTAssertTrue(result.contains("/usr/bin/java"))
    }

    func testDescription_bothEmpty() {
        let result = JavaDetailsFormatting.description(
            javaExecutablePath: "",
            versionOutput: ""
        )
        XCTAssertEqual(result, "")
    }

    func testDescription_whitespaceOnly() {
        let result = JavaDetailsFormatting.description(
            javaExecutablePath: "   ",
            versionOutput: "  "
        )
        XCTAssertEqual(result, "")
    }

    func testDescription_trimsWhitespace() {
        let result = JavaDetailsFormatting.description(
            javaExecutablePath: "  /usr/bin/java  ",
            versionOutput: "  openjdk 17.0.2  "
        )
        XCTAssertTrue(result.contains("/usr/bin/java"))
        XCTAssertTrue(result.contains("openjdk 17.0.2"))
    }
}
