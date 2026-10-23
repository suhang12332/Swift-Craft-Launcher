//
//  TemporaryDirectoryTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class TemporaryDirectoryTests: XCTestCase {
    func testCreatesDirectoryUnderPurpose() throws {
        let temporary = try TemporaryDirectory(purpose: .modpackImport)
        defer { temporary.remove() }

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporary.url.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertEqual(
            temporary.url.deletingLastPathComponent().lastPathComponent,
            TemporaryDirectoryPurpose.modpackImport.directoryName,
        )
    }

    func testCreatesDistinctDirectories() throws {
        let first = try TemporaryDirectory(purpose: .modpackImport)
        let second = try TemporaryDirectory(purpose: .modpackImport)
        defer {
            first.remove()
            second.remove()
        }

        XCTAssertNotEqual(first.url, second.url)
    }

    func testRemove_deletesOnlyOwnedDirectory() throws {
        let first = try TemporaryDirectory(purpose: .modpackImport)
        let second = try TemporaryDirectory(purpose: .modpackImport)
        defer { second.remove() }

        first.remove()

        XCTAssertFalse(FileManager.default.fileExists(atPath: first.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.url.path))
    }

    func testRemoveAll_deletesEveryDirectoryForPurpose() throws {
        let first = try TemporaryDirectory(purpose: .modpackImport)
        let second = try TemporaryDirectory(purpose: .modpackImport)
        defer {
            first.remove()
            second.remove()
        }

        TemporaryDirectory.removeAll(purpose: .modpackImport)

        XCTAssertFalse(FileManager.default.fileExists(atPath: first.url.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.url.path))
    }

    func testPurposeDirectoryNames_matchOnDiskFolderNames() {
        XCTAssertEqual(TemporaryDirectoryPurpose.modpackDownload.directoryName, "modpack_download")
        XCTAssertEqual(TemporaryDirectoryPurpose.modpackExtraction.directoryName, "modpack_extraction")
        XCTAssertEqual(TemporaryDirectoryPurpose.modpackImport.directoryName, "modpack_import")
        XCTAssertEqual(TemporaryDirectoryPurpose.modpackURLDownload.directoryName, "modpack_url_download")
        XCTAssertEqual(TemporaryDirectoryPurpose.modpackExport.directoryName, "modpack_export")
        XCTAssertEqual(TemporaryDirectoryPurpose.minecraftNativeExtraction.directoryName, "minecraft_native_extraction")
        XCTAssertEqual(TemporaryDirectoryPurpose.playerSkin.directoryName, "player_skin")
        XCTAssertEqual(TemporaryDirectoryPurpose.playerCape.directoryName, "player_cape")
        XCTAssertEqual(TemporaryDirectoryPurpose.gameIconPreview.directoryName, "game_icon_preview")
        XCTAssertEqual(TemporaryDirectoryPurpose.downloadStaging.directoryName, "download_staging")
    }

    func testTemporaryFile_writesInsidePurposeDirectory() throws {
        let temporary = try TemporaryFile(purpose: .playerSkin, fileName: "skin.png")
        defer { temporary.remove() }

        try temporary.write(Data([0x01, 0x02, 0x03]))

        XCTAssertTrue(FileManager.default.fileExists(atPath: temporary.url.path))
        XCTAssertEqual(
            temporary.url.deletingLastPathComponent().lastPathComponent,
            TemporaryDirectoryPurpose.playerSkin.directoryName,
        )
    }

    func testTemporaryFile_removeDeletesOnlyThatFile() throws {
        let first = try TemporaryFile(purpose: .playerSkin, fileName: "first.png")
        let second = try TemporaryFile(purpose: .playerSkin, fileName: "second.png")
        defer { second.remove() }

        try first.write(Data([0x01]))
        try second.write(Data([0x02]))

        first.remove()

        XCTAssertFalse(FileManager.default.fileExists(atPath: first.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.url.path))
    }

    func testTemporaryFile_isTemporary_matchesPurposeDirectories() throws {
        let temporary = try TemporaryFile(purpose: .playerCape, fileName: "cape.png")
        defer { temporary.remove() }

        XCTAssertTrue(TemporaryFile.isTemporary(temporary.url))
        XCTAssertFalse(TemporaryFile.isTemporary(URL(fileURLWithPath: "/definitely/not/a/temp/file.png")))
    }

    func testTemporaryFile_isTemporary_rejectsFilesDirectlyInTemporaryRoot() {
        let legacyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("legacy_\(UUID().uuidString).png")

        XCTAssertFalse(TemporaryFile.isTemporary(legacyURL))
    }

    func testModpackInstallPurposes_coverOnlyInstallArtifacts() {
        XCTAssertEqual(
            Set(TemporaryDirectoryPurpose.modpackInstall.map(\.directoryName)),
            [
                "modpack_download",
                "modpack_extraction",
                "modpack_import",
                "modpack_url_download",
            ],
        )
    }
}
