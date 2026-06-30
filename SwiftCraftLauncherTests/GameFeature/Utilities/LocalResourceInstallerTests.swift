//
//  LocalResourceInstallerTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class LocalResourceInstallerTests: XCTestCase {

    func testLocalResourceType_directoryName_mod() {
        XCTAssertEqual(LocalResourceInstaller.LocalResourceType.mod.directoryName, "mods")
    }

    func testLocalResourceType_directoryName_datapack() {
        XCTAssertEqual(LocalResourceInstaller.LocalResourceType.datapack.directoryName, "datapacks")
    }

    func testLocalResourceType_directoryName_resourcepack() {
        XCTAssertEqual(LocalResourceInstaller.LocalResourceType.resourcepack.directoryName, "resourcepacks")
    }

    func testLocalResourceType_allowedExtensions_mod() {
        let extensions = LocalResourceInstaller.LocalResourceType.mod.allowedExtensions
        XCTAssertTrue(extensions.contains("jar"))
        XCTAssertTrue(extensions.contains("zip"))
    }

    func testLocalResourceType_allowedExtensions_datapack() {
        let extensions = LocalResourceInstaller.LocalResourceType.datapack.allowedExtensions
        XCTAssertTrue(extensions.contains("jar"))
        XCTAssertTrue(extensions.contains("zip"))
    }

    func testLocalResourceType_allowedExtensions_resourcepack() {
        let extensions = LocalResourceInstaller.LocalResourceType.resourcepack.allowedExtensions
        XCTAssertTrue(extensions.contains("jar"))
        XCTAssertTrue(extensions.contains("zip"))
    }

    func testInstall_invalidExtension_throws() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_install_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("test.txt")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data("test".utf8))

        XCTAssertThrowsError(try LocalResourceInstaller.install(
            fileURL: fileURL,
            resourceType: .mod,
            gameRoot: tempDir
        ))
    }

    func testInstall_invalidDirectory_throws() {
        let nonExistentDir = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString)")
        let fileURL = URL(fileURLWithPath: "/tmp/test.jar")

        XCTAssertThrowsError(try LocalResourceInstaller.install(
            fileURL: fileURL,
            resourceType: .mod,
            gameRoot: nonExistentDir
        ))
    }
}
