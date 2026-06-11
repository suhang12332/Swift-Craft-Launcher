import XCTest
@testable import SwiftCraftLauncher

final class SHA1CalculatorTests: XCTestCase {

    func testSHA1_emptyData() {
        let data = Data()
        let hash = SHA1Calculator.sha1(of: data)
        XCTAssertEqual(hash, "da39a3ee5e6b4b0d3255bfef95601890afd80709")
    }

    func testSHA1_hello() {
        let data = "hello".data(using: .utf8)!
        let hash = SHA1Calculator.sha1(of: data)
        XCTAssertEqual(hash, "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d")
    }

    func testSHA1_deterministic() {
        let data = "test data".data(using: .utf8)!
        let hash1 = SHA1Calculator.sha1(of: data)
        let hash2 = SHA1Calculator.sha1(of: data)
        XCTAssertEqual(hash1, hash2)
    }

    func testSHA1_differentData_differentHash() {
        let hash1 = SHA1Calculator.sha1(of: "abc".data(using: .utf8)!)
        let hash2 = SHA1Calculator.sha1(of: "def".data(using: .utf8)!)
        XCTAssertNotEqual(hash1, hash2)
    }

    func testSHA1_40Characters() {
        let data = "test".data(using: .utf8)!
        let hash = SHA1Calculator.sha1(of: data)
        XCTAssertEqual(hash.count, 40)
    }

    func testSHA1_hexCharacters() {
        let data = "test".data(using: .utf8)!
        let hash = SHA1Calculator.sha1(of: data)
        XCTAssertNil(hash.range(of: "[^0-9a-f]", options: .regularExpression))
    }

    func testSHA1WithCryptoKit_matchesSHA1() {
        let data = "hello world".data(using: .utf8)!
        let hash1 = SHA1Calculator.sha1(of: data)
        let hash2 = SHA1Calculator.sha1WithCryptoKit(of: data)
        XCTAssertEqual(hash1, hash2)
    }

    func testSHA1WithCryptoKit_emptyData() {
        let data = Data()
        let hash = SHA1Calculator.sha1WithCryptoKit(of: data)
        XCTAssertEqual(hash, "da39a3ee5e6b4b0d3255bfef95601890afd80709")
    }

    func testDataSHA1_extension() {
        let data = "test".data(using: .utf8)!
        let hash = data.sha1
        XCTAssertEqual(hash, SHA1Calculator.sha1(of: data))
    }

    func testSHA1_sha1_ofFileAt() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let fileURL = tmpDir.appendingPathComponent("test.txt")
        try "hello".data(using: .utf8)!.write(to: fileURL)

        let hash = try SHA1Calculator.sha1(ofFileAt: fileURL)
        XCTAssertEqual(hash, "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d")
    }
}
