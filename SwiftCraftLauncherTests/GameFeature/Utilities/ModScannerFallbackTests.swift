//
//  ModScannerFallbackTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class ModScannerFallbackTests: XCTestCase {

    private lazy var modScanner = ModScanner(errorHandler: GlobalErrorHandler.shared)

    func testCreateFallbackDetail_jarFile() {
        let fileURL = URL(fileURLWithPath: "/tmp/mods/MyMod-1.0.jar")
        let detail = modScanner.createFallbackDetailFromFileName(fileURL: fileURL)

        XCTAssertEqual(detail.fileName, "MyMod-1.0.jar")
        XCTAssertEqual(detail.title, "MyMod-1.0")
        XCTAssertEqual(detail.slug, "mymod-1.0")
        XCTAssertEqual(detail.description, "local：MyMod-1.0.jar")
        XCTAssertTrue(detail.categories.contains("unknown"))
        XCTAssertEqual(detail.clientSide, "optional")
        XCTAssertEqual(detail.serverSide, "optional")
        XCTAssertEqual(detail.projectType, ResourceType.mod.rawValue)
        XCTAssertEqual(detail.downloads, 0)
        XCTAssertEqual(detail.team, "local")
        XCTAssertEqual(detail.followers, 0)
        XCTAssertNil(detail.license)
        XCTAssertNil(detail.iconUrl)
        XCTAssertNil(detail.issuesUrl)
        XCTAssertNil(detail.sourceUrl)
        XCTAssertNil(detail.wikiUrl)
        XCTAssertNil(detail.discordUrl)
        XCTAssertTrue(detail.versions.contains("unknown"))
        XCTAssertTrue(detail.gameVersions.isEmpty)
        XCTAssertTrue(detail.loaders.isEmpty)
        XCTAssertNil(detail.type)
    }

    func testCreateFallbackDetail_zipFile() {
        let fileURL = URL(fileURLWithPath: "/tmp/resourcepacks/MyPack.zip")
        let detail = modScanner.createFallbackDetailFromFileName(fileURL: fileURL)

        XCTAssertEqual(detail.fileName, "MyPack.zip")
        XCTAssertEqual(detail.title, "MyPack")
        XCTAssertEqual(detail.slug, "mypack")
    }

    func testCreateFallbackDetail_withSpaces() {
        let fileURL = URL(fileURLWithPath: "/tmp/mods/My Cool Mod.jar")
        let detail = modScanner.createFallbackDetailFromFileName(fileURL: fileURL)

        XCTAssertEqual(detail.title, "My Cool Mod")
        XCTAssertEqual(detail.slug, "my-cool-mod")
    }

    func testCreateFallbackDetail_idStartsWithFile() {
        let fileURL = URL(fileURLWithPath: "/tmp/mods/TestMod.jar")
        let detail = modScanner.createFallbackDetailFromFileName(fileURL: fileURL)

        XCTAssertTrue(detail.id.hasPrefix("file_TestMod_"))
    }

    func testCreateFallbackDetail_publishedAndUpdated_areRecent() {
        let fileURL = URL(fileURLWithPath: "/tmp/mods/Test.jar")
        let before = Date()
        let detail = modScanner.createFallbackDetailFromFileName(fileURL: fileURL)
        let after = Date()

        XCTAssertGreaterThanOrEqual(detail.published, before.addingTimeInterval(-1))
        XCTAssertLessThanOrEqual(detail.published, after.addingTimeInterval(1))
        XCTAssertGreaterThanOrEqual(detail.updated, before.addingTimeInterval(-1))
        XCTAssertLessThanOrEqual(detail.updated, after.addingTimeInterval(1))
    }
}
