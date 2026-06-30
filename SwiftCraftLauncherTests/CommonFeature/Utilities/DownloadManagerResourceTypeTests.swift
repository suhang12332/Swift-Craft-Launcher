//
//  DownloadManagerResourceTypeTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class DownloadManagerResourceTypeTests: XCTestCase {

    func testFolderName_mod() {
        XCTAssertEqual(DownloadManager.ResourceType.mod.folderName, AppConstants.DirectoryNames.mods)
    }

    func testFolderName_datapack() {
        XCTAssertEqual(DownloadManager.ResourceType.datapack.folderName, AppConstants.DirectoryNames.datapacks)
    }

    func testFolderName_shader() {
        XCTAssertEqual(DownloadManager.ResourceType.shader.folderName, AppConstants.DirectoryNames.shaderpacks)
    }

    func testFolderName_resourcepack() {
        XCTAssertEqual(DownloadManager.ResourceType.resourcepack.folderName, AppConstants.DirectoryNames.resourcepacks)
    }

    func testInitFrom_mod() {
        XCTAssertEqual(DownloadManager.ResourceType(from: "mod"), .mod)
    }

    func testInitFrom_datapack() {
        XCTAssertEqual(DownloadManager.ResourceType(from: "datapack"), .datapack)
    }

    func testInitFrom_shader() {
        XCTAssertEqual(DownloadManager.ResourceType(from: "shader"), .shader)
    }

    func testInitFrom_resourcepack() {
        XCTAssertEqual(DownloadManager.ResourceType(from: "resourcepack"), .resourcepack)
    }

    func testInitFrom_uppercase() {
        XCTAssertEqual(DownloadManager.ResourceType(from: "MOD"), .mod)
        XCTAssertEqual(DownloadManager.ResourceType(from: "DATAPACK"), .datapack)
        XCTAssertEqual(DownloadManager.ResourceType(from: "SHADER"), .shader)
        XCTAssertEqual(DownloadManager.ResourceType(from: "RESOURCEPACK"), .resourcepack)
    }

    func testInitFrom_mixedCase() {
        XCTAssertEqual(DownloadManager.ResourceType(from: "Mod"), .mod)
        XCTAssertEqual(DownloadManager.ResourceType(from: "DataPack"), .datapack)
    }

    func testInitFrom_invalid_returnsNil() {
        XCTAssertNil(DownloadManager.ResourceType(from: "invalid"))
        XCTAssertNil(DownloadManager.ResourceType(from: ""))
        XCTAssertNil(DownloadManager.ResourceType(from: "texturepack"))
        XCTAssertNil(DownloadManager.ResourceType(from: "modpack"))
    }

    func testRawValue_roundTrip() {
        for type in [DownloadManager.ResourceType.mod, .datapack, .shader, .resourcepack] {
            XCTAssertEqual(DownloadManager.ResourceType(from: type.rawValue), type)
        }
    }
}
