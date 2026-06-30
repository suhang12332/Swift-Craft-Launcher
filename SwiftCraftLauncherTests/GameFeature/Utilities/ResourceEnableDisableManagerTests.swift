//
//  ResourceEnableDisableManagerTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ResourceEnableDisableManagerTests: XCTestCase {
    func testIsDisabled_nil_returnsFalse() {
        XCTAssertFalse(ResourceEnableDisableManager.isDisabled(fileName: nil))
    }

    func testIsDisabled_disableSuffix_returnsTrue() {
        XCTAssertTrue(ResourceEnableDisableManager.isDisabled(fileName: "mod.jar.disable"))
    }

    func testIsDisabled_normalFile_returnsFalse() {
        XCTAssertFalse(ResourceEnableDisableManager.isDisabled(fileName: "mod.jar"))
    }

    func testIsDisabled_emptyString_returnsFalse() {
        XCTAssertFalse(ResourceEnableDisableManager.isDisabled(fileName: ""))
    }

    func testIsDisabled_disableSuffixOnly_returnsTrue() {
        XCTAssertTrue(ResourceEnableDisableManager.isDisabled(fileName: ".disable"))
    }

    func testIsDisabled_partialDisableSuffix_returnsFalse() {
        XCTAssertFalse(ResourceEnableDisableManager.isDisabled(fileName: "mod.disable.jar"))
    }

    func testToggleDisableState_enableToDisable() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let testFile = "test.jar"
        let fileURL = tmpDir.appendingPathComponent(testFile)
        try Data("test".utf8).write(to: fileURL)

        let result = try ResourceEnableDisableManager.toggleDisableState(
            fileName: testFile,
            resourceDir: tmpDir,
        )
        XCTAssertEqual(result, "test.jar.disable")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmpDir.appendingPathComponent(result).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testToggleDisableState_disableToEnable() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let testFile = "test.jar.disable"
        let fileURL = tmpDir.appendingPathComponent(testFile)
        try Data("test".utf8).write(to: fileURL)

        let result = try ResourceEnableDisableManager.toggleDisableState(
            fileName: testFile,
            resourceDir: tmpDir,
        )
        XCTAssertEqual(result, "test.jar")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmpDir.appendingPathComponent(result).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
