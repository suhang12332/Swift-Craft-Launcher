//
//  APIKeyObfuscatorTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class APIKeyObfuscatorTests: XCTestCase {
    func testDecryptClientID_emptyString() {
        _ = Obfuscator.decryptClientID("")
    }

    func testDecryptClientID_consistentResults() {
        let input = "AAAAAAAA BBBBBBBB CCCCCCCC DDDDDDDD EEEEEEEE FFFFFFFF".replacingOccurrences(of: " ", with: "")
        let result1 = Obfuscator.decryptClientID(input)
        let result2 = Obfuscator.decryptClientID(input)
        XCTAssertEqual(result1, result2)
    }

    func testDecryptAPIKey_consistentResults() {
        let input = "AAAAAAAA BBBBBBBB CCCCCCCC DDDDDDDD EEEEEEEE FFFFFFFF".replacingOccurrences(of: " ", with: "")
        let result1 = Obfuscator.decryptAPIKey(input)
        let result2 = Obfuscator.decryptAPIKey(input)
        XCTAssertEqual(result1, result2)
    }

    func testDecryptAPIKey_longString() {
        let input = String(repeating: "A", count: 64)
        _ = Obfuscator.decryptAPIKey(input)
    }

    // MARK: - Out-of-bounds regression (String index safety)

    func testDecryptAPIKey_emptyString_doesNotCrash() {
        _ = Obfuscator.decryptAPIKey("")
    }

    func testDecryptAPIKey_shortString_notMultipleOf8_doesNotCrash() {
        // Length 21 — exactly the "$(CURSEFORGE_API_KEY)" placeholder length
        // that appears when the build setting is not substituted. Previously
        // this trapped with "String index is out of bounds".
        _ = Obfuscator.decryptAPIKey(String(repeating: "A", count: 21))
    }

    func testDecryptAPIKey_length5_doesNotCrash() {
        _ = Obfuscator.decryptAPIKey("ABCDE")
    }

    func testDecryptAPIKey_length1_doesNotCrash() {
        _ = Obfuscator.decryptAPIKey("A")
    }

    func testDecryptAPIKey_length7_doesNotCrash() {
        _ = Obfuscator.decryptAPIKey(String(repeating: "A", count: 7))
    }

    func testDecryptAPIKey_length9_doesNotCrash() {
        _ = Obfuscator.decryptAPIKey(String(repeating: "A", count: 9))
    }

    func testDecryptAPIKey_placeholderString_doesNotCrash() {
        // Simulates an unsubstituted build-variable placeholder.
        _ = Obfuscator.decryptAPIKey("$(CURSEFORGE_API_KEY)")
    }
}
