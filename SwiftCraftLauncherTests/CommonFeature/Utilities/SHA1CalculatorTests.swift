//
//  SHA1CalculatorTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class SHA1CalculatorTests: XCTestCase {
    private var tmpDir: URL?

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sha1-tests-\(UUID().uuidString)", isDirectory: true)
        guard let tmpDir else { return }
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tmpDir {
            try? FileManager.default.removeItem(at: tmpDir)
        }
        super.tearDown()
    }

    private func tmpFile(_ name: String) -> URL {
        guard let tmpDir else { fatalError("tmpDir not set") }
        return tmpDir.appendingPathComponent(name)
    }

    func testSha1_ofData_knownValue() {
        let hash = SHA1Calculator.sha1(of: Data("hello".utf8))
        XCTAssertEqual(hash, "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d")
    }

    func testSha1_ofData_emptyData() {
        let hash = SHA1Calculator.sha1(of: Data())
        XCTAssertEqual(hash, "da39a3ee5e6b4b0d3255bfef95601890afd80709")
    }

    func testSha1_ofData_deterministic() {
        let data = Data("test".utf8)
        XCTAssertEqual(SHA1Calculator.sha1(of: data), SHA1Calculator.sha1(of: data))
    }

    func testSha1_ofData_differentInput_differentHash() {
        XCTAssertNotEqual(
            SHA1Calculator.sha1(of: Data("a".utf8)),
            SHA1Calculator.sha1(of: Data("b".utf8)),
        )
    }

    func testSha1_ofData_binaryData() {
        XCTAssertEqual(SHA1Calculator.sha1(of: Data([0x00, 0xFF, 0x01, 0x02])).count, 40)
    }

    func testSha1_ofFile_knownContent() throws {
        let file = tmpFile("test.txt")
        try Data("hello".utf8).write(to: file)
        XCTAssertEqual(try SHA1Calculator.sha1(ofFileAt: file), "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d")
    }

    func testSha1_ofFile_matchesDataHash() throws {
        let content = "consistent content"
        let file = tmpFile("test.txt")
        try Data(content.utf8).write(to: file)
        XCTAssertEqual(try SHA1Calculator.sha1(ofFileAt: file), SHA1Calculator.sha1(of: Data(content.utf8)))
    }

    func testSha1_ofFile_emptyFile() throws {
        let file = tmpFile("empty.txt")
        try Data().write(to: file)
        XCTAssertEqual(try SHA1Calculator.sha1(ofFileAt: file), "da39a3ee5e6b4b0d3255bfef95601890afd80709")
    }

    func testSha1_ofFile_nonExistent_throws() {
        let file = tmpFile("nope.txt")
        XCTAssertThrowsError(try SHA1Calculator.sha1(ofFileAt: file))
    }

    func testSha1WithCryptoKit_knownValue() {
        let hash = SHA1Calculator.sha1WithCryptoKit(of: Data("hello".utf8))
        XCTAssertEqual(hash, "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d")
    }

    func testSha1WithCryptoKit_matchesSha1() {
        let data = Data("test data".utf8)
        XCTAssertEqual(SHA1Calculator.sha1(of: data), SHA1Calculator.sha1WithCryptoKit(of: data))
    }

    func testDataSha1_extension() {
        let data = Data("hello".utf8)
        XCTAssertEqual(data.sha1, "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d")
    }
}
