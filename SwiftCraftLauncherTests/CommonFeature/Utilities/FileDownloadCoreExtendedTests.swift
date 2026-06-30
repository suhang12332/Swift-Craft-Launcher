//
//  FileDownloadCoreExtendedTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class FileDownloadCoreExtendedTests: XCTestCase {

    private var tmpDir: URL?

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fdc-tests-\(UUID().uuidString)", isDirectory: true)
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

    func testParseURL_https() throws {
        let url = try FileDownloadCore.parseURL(from: "https://example.com/file.jar")
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "example.com")
    }

    func testParseURL_http() throws {
        let url = try FileDownloadCore.parseURL(from: "http://example.com/file.jar")
        XCTAssertEqual(url.scheme, "http")
    }

    func testParseURL_withPath() throws {
        let url = try FileDownloadCore.parseURL(from: "https://example.com/path/to/file.jar")
        XCTAssertEqual(url.path, "/path/to/file.jar")
    }

    func testParseURL_emptyString_throws() {
        XCTAssertThrowsError(try FileDownloadCore.parseURL(from: "")) { error in
            let globalError = error as? GlobalError
            XCTAssertEqual(globalError?.i18nKey, "error.validation.invalid_download_url")
        }
    }

    func testParseURL_spacesInUrl_throws() {
        XCTAssertThrowsError(try FileDownloadCore.parseURL(from: "https://exam ple.com/file.jar"))
    }

    func testNormalizedDownloadURL_nonGitHub_passthrough() throws {
        let url = try FileDownloadCore.parseURL(from: "https://example.com/file.jar")
        let result = FileDownloadCore.normalizedDownloadURL(from: url)
        XCTAssertEqual(result.absoluteString, "https://example.com/file.jar")
    }

    func testNormalizedDownloadURL_githubUrl() throws {
        let url = try FileDownloadCore.parseURL(from: "https://github.com/user/repo/releases/download/v1.0/file.jar")
        let result = FileDownloadCore.normalizedDownloadURL(from: url)
        XCTAssertTrue(
            result.absoluteString.contains("github.com") || result.absoluteString.contains("gh-proxy")
        )
    }

    func testExistingFileSizeIfReusable_missingFile_returnsNil() {
        let url = tmpFile("missing-\(UUID().uuidString).jar")
        XCTAssertNil(FileDownloadCore.existingFileSizeIfReusable(at: url, expectedSha1: nil))
    }

    func testExistingFileSizeIfReusable_existingFile_returnsSize() throws {
        let file = tmpFile("test.jar")
        let data = Data("hello".utf8)
        try data.write(to: file)
        XCTAssertEqual(FileDownloadCore.existingFileSizeIfReusable(at: file, expectedSha1: nil), Int64(data.count))
    }

    func testExistingFileSizeIfReusable_matchingSha1_returnsSize() throws {
        let file = tmpFile("test.jar")
        let data = Data("hello".utf8)
        try data.write(to: file)
        let sha1 = SHA1Calculator.sha1(of: data)
        XCTAssertEqual(FileDownloadCore.existingFileSizeIfReusable(at: file, expectedSha1: sha1), Int64(data.count))
    }

    func testExistingFileSizeIfReusable_wrongSha1_returnsNil() throws {
        let file = tmpFile("test.jar")
        try Data("hello".utf8).write(to: file)
        XCTAssertNil(FileDownloadCore.existingFileSizeIfReusable(at: file, expectedSha1: "wrong_sha1"))
    }

    func testExistingFileSizeIfReusable_emptySha1_returnsSize() throws {
        let file = tmpFile("test.jar")
        let data = Data("hello".utf8)
        try data.write(to: file)
        XCTAssertEqual(FileDownloadCore.existingFileSizeIfReusable(at: file, expectedSha1: ""), Int64(data.count))
    }

    func testValidateSHA1IfNeeded_nilExpected_noError() throws {
        let file = tmpFile("test.jar")
        try Data("hello".utf8).write(to: file)
        XCTAssertNoThrow(try FileDownloadCore.validateSHA1IfNeeded(for: file, expectedSha1: nil))
    }

    func testValidateSHA1IfNeeded_emptyExpected_noError() throws {
        let file = tmpFile("test.jar")
        try Data("hello".utf8).write(to: file)
        XCTAssertNoThrow(try FileDownloadCore.validateSHA1IfNeeded(for: file, expectedSha1: ""))
    }

    func testValidateSHA1IfNeeded_matchingSha1_noError() throws {
        let file = tmpFile("test.jar")
        let data = Data("hello".utf8)
        try data.write(to: file)
        let sha1 = SHA1Calculator.sha1(of: data)
        XCTAssertNoThrow(try FileDownloadCore.validateSHA1IfNeeded(for: file, expectedSha1: sha1))
    }

    func testValidateSHA1IfNeeded_wrongSha1_throws() throws {
        let file = tmpFile("test.jar")
        try Data("hello".utf8).write(to: file)
        XCTAssertThrowsError(try FileDownloadCore.validateSHA1IfNeeded(for: file, expectedSha1: "wrong")) { error in
            let globalError = error as? GlobalError
            XCTAssertEqual(globalError?.i18nKey, "error.validation.sha1_check_failed")
        }
    }

    func testMoveDownloadedFile_toNewDestination() throws {
        let src = tmpFile("src.jar")
        let dst = tmpFile("dst.jar")
        try Data("content".utf8).write(to: src)

        try FileDownloadCore.moveDownloadedFile(from: src, to: dst)

        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: src.path))
        XCTAssertEqual(try Data(contentsOf: dst), Data("content".utf8))
    }

    func testMoveDownloadedFile_overwritesExisting() throws {
        let src = tmpFile("src.jar")
        let dst = tmpFile("dst.jar")
        try Data("old".utf8).write(to: dst)
        try Data("new".utf8).write(to: src)

        try FileDownloadCore.moveDownloadedFile(from: src, to: dst)

        XCTAssertEqual(try Data(contentsOf: dst), Data("new".utf8))
    }

    func testEnsureParentDirectory_createsNestedDir() throws {
        let dest = tmpFile("sub/deep/file.jar")
        XCTAssertNoThrow(try FileDownloadCore.ensureParentDirectory(for: dest))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.deletingLastPathComponent().path))
    }

    func testEnsureParentDirectory_existingDir_noError() throws {
        let dest = tmpFile("file.jar")
        XCTAssertNoThrow(try FileDownloadCore.ensureParentDirectory(for: dest))
    }
}
