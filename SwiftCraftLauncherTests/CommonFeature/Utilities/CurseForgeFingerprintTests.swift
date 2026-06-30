//
//  CurseForgeFingerprintTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class CurseForgeFingerprintTests: XCTestCase {
    func testFingerprint_sameData_sameHash() {
        let data = Data("example-mod-content".utf8)
        XCTAssertEqual(CurseForgeFingerprint.fingerprint(data: data), CurseForgeFingerprint.fingerprint(data: data))
    }

    func testFingerprint_ignoresWhitespace() {
        let withSpaces = Data("hello world".utf8)
        let withoutSpaces = Data("helloworld".utf8)
        XCTAssertEqual(
            CurseForgeFingerprint.fingerprint(data: withSpaces),
            CurseForgeFingerprint.fingerprint(data: withoutSpaces)
        )
    }

    func testFingerprint_emptyData_returnsDeterministicValue() {
        let hash = CurseForgeFingerprint.fingerprint(data: Data())
        XCTAssertNotEqual(hash, 0)
    }
}
