//
//  DownloadManagerResourceTypeTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class DownloadManagerResourceTypeTests: XCTestCase {
    func testFolderName_mod() {
        XCTAssertEqual(ResourceType.mod.folderName, AppConstants.DirectoryNames.mods)
    }

    func testFolderName_datapack() {
        XCTAssertEqual(ResourceType.datapack.folderName, AppConstants.DirectoryNames.datapacks)
    }

    func testFolderName_shader() {
        XCTAssertEqual(ResourceType.shader.folderName, AppConstants.DirectoryNames.shaderpacks)
    }

    func testFolderName_resourcepack() {
        XCTAssertEqual(ResourceType.resourcepack.folderName, AppConstants.DirectoryNames.resourcepacks)
    }

    func testFolderName_modpack_returnsEmpty() {
        XCTAssertEqual(ResourceType.modpack.folderName, "")
    }

    func testInitFrom_mod() {
        XCTAssertEqual(ResourceType(from: "mod"), .mod)
    }

    func testInitFrom_datapack() {
        XCTAssertEqual(ResourceType(from: "datapack"), .datapack)
    }

    func testInitFrom_shader() {
        XCTAssertEqual(ResourceType(from: "shader"), .shader)
    }

    func testInitFrom_resourcepack() {
        XCTAssertEqual(ResourceType(from: "resourcepack"), .resourcepack)
    }

    func testInitFrom_uppercase() {
        XCTAssertEqual(ResourceType(from: "MOD"), .mod)
        XCTAssertEqual(ResourceType(from: "DATAPACK"), .datapack)
        XCTAssertEqual(ResourceType(from: "SHADER"), .shader)
        XCTAssertEqual(ResourceType(from: "RESOURCEPACK"), .resourcepack)
    }

    func testInitFrom_mixedCase() {
        XCTAssertEqual(ResourceType(from: "Mod"), .mod)
        XCTAssertEqual(ResourceType(from: "DataPack"), .datapack)
    }

    func testInitFrom_invalid_returnsNil() {
        XCTAssertNil(ResourceType(from: "invalid"))
        XCTAssertNil(ResourceType(from: ""))
        XCTAssertNil(ResourceType(from: "texturepack"))
    }

    func testRawValue_roundTrip() {
        for type in [ResourceType.mod, .datapack, .shader, .resourcepack] {
            XCTAssertEqual(ResourceType(from: type.rawValue), type)
        }
    }
}
