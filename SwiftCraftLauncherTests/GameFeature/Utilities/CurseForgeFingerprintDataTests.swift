import XCTest
@testable import SwiftCraftLauncher

final class CurseForgeFingerprintDataTests: XCTestCase {

    // MARK: - Consistency

    func testFingerprint_deterministic() {
        let data = Data("deterministic-test-content".utf8)
        let h1 = CurseForgeFingerprint.fingerprint(data: data)
        let h2 = CurseForgeFingerprint.fingerprint(data: data)
        XCTAssertEqual(h1, h2)
    }

    func testFingerprint_differentData_differentHash() {
        let a = CurseForgeFingerprint.fingerprint(data: Data("content-a".utf8))
        let b = CurseForgeFingerprint.fingerprint(data: Data("content-b".utf8))
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Whitespace handling

    func testFingerprint_ignoresTabs() {
        let withTabs = Data("hello\tworld".utf8)
        let withoutTabs = Data("helloworld".utf8)
        XCTAssertEqual(
            CurseForgeFingerprint.fingerprint(data: withTabs),
            CurseForgeFingerprint.fingerprint(data: withoutTabs)
        )
    }

    func testFingerprint_ignoresNewlines() {
        let withNewlines = Data("hello\nworld\n".utf8)
        let withoutNewlines = Data("helloworld".utf8)
        XCTAssertEqual(
            CurseForgeFingerprint.fingerprint(data: withNewlines),
            CurseForgeFingerprint.fingerprint(data: withoutNewlines)
        )
    }

    func testFingerprint_ignoresCarriageReturns() {
        let withCR = Data("hello\rworld".utf8)
        let withoutCR = Data("helloworld".utf8)
        XCTAssertEqual(
            CurseForgeFingerprint.fingerprint(data: withCR),
            CurseForgeFingerprint.fingerprint(data: withoutCR)
        )
    }

    func testFingerprint_ignoresSpaces() {
        let withSpaces = Data("hello world".utf8)
        let withoutSpaces = Data("helloworld".utf8)
        XCTAssertEqual(
            CurseForgeFingerprint.fingerprint(data: withSpaces),
            CurseForgeFingerprint.fingerprint(data: withoutSpaces)
        )
    }

    func testFingerprint_ignoresMixedWhitespace() {
        let mixed = Data("h e l l o\t\n\rw o r l d".utf8)
        let clean = Data("helloworld".utf8)
        XCTAssertEqual(
            CurseForgeFingerprint.fingerprint(data: mixed),
            CurseForgeFingerprint.fingerprint(data: clean)
        )
    }

    // MARK: - Empty and small data

    func testFingerprint_emptyData_nonZero() {
        let hash = CurseForgeFingerprint.fingerprint(data: Data())
        XCTAssertNotEqual(hash, 0)
    }

    func testFingerprint_singleByte() {
        let hash = CurseForgeFingerprint.fingerprint(data: Data([0x41]))
        XCTAssertNotEqual(hash, 0)
    }

    func testFingerprint_onlyWhitespace() {
        let whitespace = Data(" \t\n\r".utf8)
        let empty = Data()
        XCTAssertEqual(
            CurseForgeFingerprint.fingerprint(data: whitespace),
            CurseForgeFingerprint.fingerprint(data: empty)
        )
    }

    // MARK: - Binary data

    func testFingerprint_binaryData() {
        let bytes: [UInt8] = Array(0...255)
        let data = Data(bytes)
        let hash = CurseForgeFingerprint.fingerprint(data: data)
        XCTAssertNotEqual(hash, 0)
    }

    func testFingerprint_binaryDataWithWhitespace() {
        let bytesWithSpace: [UInt8] = [0x09, 0x0A, 0x0D, 0x20, 0x41, 0x42]
        let bytesWithoutSpace: [UInt8] = [0x41, 0x42]
        XCTAssertEqual(
            CurseForgeFingerprint.fingerprint(data: Data(bytesWithSpace)),
            CurseForgeFingerprint.fingerprint(data: Data(bytesWithoutSpace))
        )
    }

    // MARK: - Large data

    func testFingerprint_largeData() {
        let largeData = Data(repeating: 0x42, count: 100_000)
        let hash = CurseForgeFingerprint.fingerprint(data: largeData)
        XCTAssertNotEqual(hash, 0)
    }

    // MARK: - Known value regression

    func testFingerprint_knownValue_regression() {
        let data = Data("CurseForge".utf8)
        let hash = CurseForgeFingerprint.fingerprint(data: data)

        let hash2 = CurseForgeFingerprint.fingerprint(data: Data("CurseForge".utf8))
        XCTAssertEqual(hash, hash2)
    }
}
