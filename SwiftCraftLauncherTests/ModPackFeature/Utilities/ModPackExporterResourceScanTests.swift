//
//  ModPackExporterResourceScanTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

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

    func testShouldScanForModrinth_mods() {
        let file = gameDirectory.appendingPathComponent("mods/test.jar")
        XCTAssertTrue(ModPackExporter.shouldScanForModrinth(file, gameDirectory: gameDirectory))
    }

    func testShouldScanForModrinth_resourcepacks() {
        let file = gameDirectory.appendingPathComponent("resourcepacks/pack.zip")
        XCTAssertTrue(ModPackExporter.shouldScanForModrinth(file, gameDirectory: gameDirectory))
    }

    func testShouldScanForModrinth_datapacks() {
        let file = gameDirectory.appendingPathComponent("datapacks/datapack.zip")
        XCTAssertTrue(ModPackExporter.shouldScanForModrinth(file, gameDirectory: gameDirectory))
    }

    func testShouldScanForModrinth_shaderpacks() {
        let file = gameDirectory.appendingPathComponent("shaderpacks/shader.zip")
        XCTAssertTrue(ModPackExporter.shouldScanForModrinth(file, gameDirectory: gameDirectory))
    }

    func testShouldScanForModrinth_config_returnsFalse() {
        let file = gameDirectory.appendingPathComponent("config/settings.json")
        XCTAssertFalse(ModPackExporter.shouldScanForModrinth(file, gameDirectory: gameDirectory))
    }

    func testShouldScanForModrinth_versions_returnsFalse() {
        let file = gameDirectory.appendingPathComponent("versions/1.20.1/client.jar")
        XCTAssertFalse(ModPackExporter.shouldScanForModrinth(file, gameDirectory: gameDirectory))
    }

    func testShouldScanForCurseForge_modsJar() {
        let file = gameDirectory.appendingPathComponent("mods/test.jar")
        XCTAssertTrue(ModPackExporter.shouldScanForCurseForge(file, gameDirectory: gameDirectory))
    }

    func testShouldScanForCurseForge_modsZip_returnsFalse() {
        let file = gameDirectory.appendingPathComponent("mods/test.zip")
        XCTAssertFalse(ModPackExporter.shouldScanForCurseForge(file, gameDirectory: gameDirectory))
    }

    func testShouldScanForCurseForge_resourcepacksJar_returnsFalse() {
        let file = gameDirectory.appendingPathComponent("resourcepacks/pack.jar")
        XCTAssertFalse(ModPackExporter.shouldScanForCurseForge(file, gameDirectory: gameDirectory))
    }

    func testShouldScanForCurseForge_config_returnsFalse() {
        let file = gameDirectory.appendingPathComponent("config/settings.json")
        XCTAssertFalse(ModPackExporter.shouldScanForCurseForge(file, gameDirectory: gameDirectory))
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

    func testInferOverridesSubdirectory_mods() {
        let file = gameDirectory.appendingPathComponent("mods/test.jar")
        let result = ModPackExporter.inferOverridesSubdirectory(for: file, gameDirectory: gameDirectory)
        XCTAssertEqual(result, "mods")
    }

    func testInferOverridesSubdirectory_resourcepacks() {
        let file = gameDirectory.appendingPathComponent("resourcepacks/pack.zip")
        let result = ModPackExporter.inferOverridesSubdirectory(for: file, gameDirectory: gameDirectory)
        XCTAssertEqual(result, "resourcepacks")
    }

    func testInferOverridesSubdirectory_datapacks() {
        let file = gameDirectory.appendingPathComponent("datapacks/data.zip")
        let result = ModPackExporter.inferOverridesSubdirectory(for: file, gameDirectory: gameDirectory)
        XCTAssertEqual(result, "datapacks")
    }

    func testInferOverridesSubdirectory_shaderpacks() {
        let file = gameDirectory.appendingPathComponent("shaderpacks/shader.zip")
        let result = ModPackExporter.inferOverridesSubdirectory(for: file, gameDirectory: gameDirectory)
        XCTAssertEqual(result, "shaderpacks")
    }

    func testInferOverridesSubdirectory_unknownDir_fallsBackToRelativePath() {
        let file = gameDirectory.appendingPathComponent("config/settings.json")
        let result = ModPackExporter.inferOverridesSubdirectory(for: file, gameDirectory: gameDirectory)
        XCTAssertEqual(result, "config")
    }

    func testInferOverridesSubdirectory_caseInsensitive() {
        let file = gameDirectory.appendingPathComponent("MODS/test.jar")
        let result = ModPackExporter.inferOverridesSubdirectory(for: file, gameDirectory: gameDirectory)
        XCTAssertEqual(result, "mods")
    }
}
