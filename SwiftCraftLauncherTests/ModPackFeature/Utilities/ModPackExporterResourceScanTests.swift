//
//  ModPackExporterResourceScanTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ModPackExporterResourceScanTests: XCTestCase {
    private let gameDirectory = URL(fileURLWithPath: "/tmp/testgame")

    func testTopLevelDirectoryName_modsFolder() {
        let file = gameDirectory.appendingPathComponent("mods/test.jar")
        let result = ModPackExporter.topLevelDirectoryName(of: file, gameDirectory: gameDirectory)
        XCTAssertEqual(result, "mods")
    }

    func testTopLevelDirectoryName_resourcepacksFolder() {
        let file = gameDirectory.appendingPathComponent("resourcepacks/pack.zip")
        let result = ModPackExporter.topLevelDirectoryName(of: file, gameDirectory: gameDirectory)
        XCTAssertEqual(result, "resourcepacks")
    }

    func testTopLevelDirectoryName_configFolder() {
        let file = gameDirectory.appendingPathComponent("config/settings.json")
        let result = ModPackExporter.topLevelDirectoryName(of: file, gameDirectory: gameDirectory)
        XCTAssertEqual(result, "config")
    }

    func testTopLevelDirectoryName_fileAtRoot() {
        let file = gameDirectory.appendingPathComponent("options.txt")
        let result = ModPackExporter.topLevelDirectoryName(of: file, gameDirectory: gameDirectory)
        XCTAssertEqual(result, "options.txt")
    }

    func testTopLevelDirectoryName_fileOutsideRoot() {
        let file = URL(fileURLWithPath: "/tmp/other/file.jar")
        let result = ModPackExporter.topLevelDirectoryName(of: file, gameDirectory: gameDirectory)
        XCTAssertNil(result)
    }

    func testShouldScanResource_modsJar() {
        let file = gameDirectory.appendingPathComponent("mods/test.jar")
        XCTAssertTrue(ModPackExporter.shouldScanResource(file, gameDirectory: gameDirectory))
    }

    func testShouldScanResource_modsZip() {
        let file = gameDirectory.appendingPathComponent("mods/test.zip")
        XCTAssertTrue(ModPackExporter.shouldScanResource(file, gameDirectory: gameDirectory))
    }

    func testShouldScanResource_resourcepacks() {
        let file = gameDirectory.appendingPathComponent("resourcepacks/pack.zip")
        XCTAssertTrue(ModPackExporter.shouldScanResource(file, gameDirectory: gameDirectory))
    }

    func testShouldScanResource_datapacks() {
        let file = gameDirectory.appendingPathComponent("datapacks/datapack.zip")
        XCTAssertTrue(ModPackExporter.shouldScanResource(file, gameDirectory: gameDirectory))
    }

    func testShouldScanResource_shaderpacks() {
        let file = gameDirectory.appendingPathComponent("shaderpacks/shader.zip")
        XCTAssertTrue(ModPackExporter.shouldScanResource(file, gameDirectory: gameDirectory))
    }

    func testShouldScanResource_config_returnsFalse() {
        let file = gameDirectory.appendingPathComponent("config/settings.json")
        XCTAssertFalse(ModPackExporter.shouldScanResource(file, gameDirectory: gameDirectory))
    }

    func testShouldScanResource_nonJarZipInMods_returnsFalse() {
        let file = gameDirectory.appendingPathComponent("mods/readme.txt")
        XCTAssertFalse(ModPackExporter.shouldScanResource(file, gameDirectory: gameDirectory))
    }

    func testShouldScanResource_versions_returnsFalse() {
        let file = gameDirectory.appendingPathComponent("versions/1.20.1/client.jar")
        XCTAssertFalse(ModPackExporter.shouldScanResource(file, gameDirectory: gameDirectory))
    }

    func testMakeRelativePath_modsFolder() {
        let file = gameDirectory.appendingPathComponent("mods/test.jar")
        let result = ModPackExporter.makeRelativePath(for: file, gameDirectory: gameDirectory)
        XCTAssertEqual(result, "mods")
    }

    func testMakeRelativePath_nestedPath() {
        let file = gameDirectory.appendingPathComponent("mods/subfolder/test.jar")
        let result = ModPackExporter.makeRelativePath(for: file, gameDirectory: gameDirectory)
        XCTAssertEqual(result, "mods/subfolder")
    }

    func testMakeRelativePath_fileAtRoot() {
        let file = gameDirectory.appendingPathComponent("options.txt")
        let result = ModPackExporter.makeRelativePath(for: file, gameDirectory: gameDirectory)
        XCTAssertEqual(result, "")
    }

    func testMakeRelativePath_fileOutsideRoot() {
        let file = URL(fileURLWithPath: "/tmp/other/file.jar")
        let result = ModPackExporter.makeRelativePath(for: file, gameDirectory: gameDirectory)
        XCTAssertEqual(result, "")
    }
}
