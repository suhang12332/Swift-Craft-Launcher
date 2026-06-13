import XCTest
@testable import SwiftCraftLauncher

final class APIKeyObfuscatorTests: XCTestCase {

    // MARK: - decryptClientID

    func testDecryptClientID_emptyString() {
        _ = Obfuscator.decryptClientID("")
    }

    func testDecryptClientID_consistentResults() {
        let input = "AAAAAAAA BBBBBBBB CCCCCCCC DDDDDDDD EEEEEEEE FFFFFFFF".replacingOccurrences(of: " ", with: "")
        let result1 = Obfuscator.decryptClientID(input)
        let result2 = Obfuscator.decryptClientID(input)
        XCTAssertEqual(result1, result2)
    }

    // MARK: - decryptAPIKey

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
}
