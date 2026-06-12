import XCTest
@testable import SwiftCraftLauncher

final class SHA1CalculatorTests: XCTestCase {

    private var tmpDir: URL!

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sha1-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        super.tearDown()
    }

    // MARK: - sha1(of:) Data

    func testSha1_ofData_knownValue() {
        let data = Data("hello".utf8)
        let hash = SHA1Calculator.sha1(of: data)
        XCTAssertEqual(hash, "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d")
    }

    func testSha1_ofData_emptyData() {
        let hash = SHA1Calculator.sha1(of: Data())
        XCTAssertEqual(hash, "da39a3ee5e6b4b0d3255bfef95601890afd80709")
    }

    func testSha1_ofData_deterministic() {
        let data = Data("test".utf8)
        let hash1 = SHA1Calculator.sha1(of: data)
        let hash2 = SHA1Calculator.sha1(of: data)
        XCTAssertEqual(hash1, hash2)
    }

    func testSha1_ofData_differentInput_differentHash() {
        let hash1 = SHA1Calculator.sha1(of: Data("a".utf8))
        let hash2 = SHA1Calculator.sha1(of: Data("b".utf8))
        XCTAssertNotEqual(hash1, hash2)
    }

    func testSha1_ofData_binaryData() {
        let data = Data([0x00, 0xFF, 0x01, 0x02])
        let hash = SHA1Calculator.sha1(of: data)
        XCTAssertEqual(hash.count, 40)
    }

    // MARK: - sha1(ofFileAt:) file

    func testSha1_ofFile_knownContent() throws {
        let fileURL = tmpDir.appendingPathComponent("test.txt")
        try Data("hello".utf8).write(to: fileURL)

        let hash = try SHA1Calculator.sha1(ofFileAt: fileURL)
        XCTAssertEqual(hash, "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d")
    }

    func testSha1_ofFile_matchesDataHash() throws {
        let content = "consistent content"
        let fileURL = tmpDir.appendingPathComponent("test.txt")
        try Data(content.utf8).write(to: fileURL)

        let fileHash = try SHA1Calculator.sha1(ofFileAt: fileURL)
        let dataHash = SHA1Calculator.sha1(of: Data(content.utf8))
        XCTAssertEqual(fileHash, dataHash)
    }

    func testSha1_ofFile_deterministic() throws {
        let fileURL = tmpDir.appendingPathComponent("test.txt")
        try Data("deterministic".utf8).write(to: fileURL)

        let hash1 = try SHA1Calculator.sha1(ofFileAt: fileURL)
        let hash2 = try SHA1Calculator.sha1(ofFileAt: fileURL)
        XCTAssertEqual(hash1, hash2)
    }

    func testSha1_ofFile_emptyFile() throws {
        let fileURL = tmpDir.appendingPathComponent("empty.txt")
        try Data().write(to: fileURL)

        let hash = try SHA1Calculator.sha1(ofFileAt: fileURL)
        XCTAssertEqual(hash, "da39a3ee5e6b4b0d3255bfef95601890afd80709")
    }
}
