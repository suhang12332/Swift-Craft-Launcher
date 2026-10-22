//
//  ModPackExporterExtendedTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ModPackExporterExtendedTests: XCTestCase {
    func testExportResult_successWithMessage() {
        let result = ModPackExporter.ExportResult(
            success: true,
            outputPath: URL(fileURLWithPath: "/tmp/pack.mrpack"),
            error: nil,
            message: "Export completed successfully",
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.message, "Export completed successfully")
        XCTAssertNil(result.error)
    }

    func testExportResult_failureWithError() {
        let error = NSError(domain: "export", code: 42, userInfo: [NSLocalizedDescriptionKey: "Disk full"])
        let result = ModPackExporter.ExportResult(
            success: false,
            outputPath: nil,
            error: error,
            message: "导出失败: Disk full",
        )

        XCTAssertFalse(result.success)
        XCTAssertNil(result.outputPath)
        XCTAssertEqual((result.error as? NSError)?.code, 42)
    }

    func testExportResult_cancellationError() {
        let error = CancellationError()
        let result = ModPackExporter.ExportResult(
            success: false,
            outputPath: nil,
            error: error,
            message: "已取消",
        )

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.error is CancellationError)
        XCTAssertEqual(result.message, "已取消")
    }

    func testProgressItem_zeroProgress() {
        let item = ModPackExporter.ExportProgress.ProgressItem(
            title: "Start",
            progress: 0.0,
            currentFile: "",
            completed: 0,
            total: 100,
        )

        XCTAssertEqual(item.progress, 0.0)
        XCTAssertEqual(item.completed, 0)
        XCTAssertTrue(item.currentFile.isEmpty)
    }

    func testProgressItem_completeProgress() {
        let item = ModPackExporter.ExportProgress.ProgressItem(
            title: "Done",
            progress: 1.0,
            currentFile: "last.jar",
            completed: 100,
            total: 100,
        )

        XCTAssertEqual(item.progress, 1.0)
        XCTAssertEqual(item.completed, item.total)
    }

    func testProgressItem_bothProgressItems() {
        let scan = ModPackExporter.ExportProgress.ProgressItem(
            title: "Scan",
            progress: 0.5,
            currentFile: "a.jar",
            completed: 5,
            total: 10,
        )
        let copy = ModPackExporter.ExportProgress.ProgressItem(
            title: "Copy",
            progress: 0.3,
            currentFile: "b.jar",
            completed: 3,
            total: 10,
        )
        let progress = ModPackExporter.ExportProgress(scanProgress: scan, copyProgress: copy)

        XCTAssertNotNil(progress.scanProgress)
        XCTAssertNotNil(progress.copyProgress)
        XCTAssertEqual(progress.scanProgress?.completed, 5)
        XCTAssertEqual(progress.copyProgress?.completed, 3)
    }

    func testCurseForgeModListItem_allFields() {
        let item = ModPackExporter.CurseForgeModListItem(
            projectID: 999_999,
            fileName: "awesome-mod-3.0.jar",
        )

        XCTAssertEqual(item.projectID, 999_999)
        XCTAssertEqual(item.fileName, "awesome-mod-3.0.jar")
    }

    func testCurseForgeModListItem_zeroIds() {
        let item = ModPackExporter.CurseForgeModListItem(
            projectID: 0,
            fileName: "empty.jar",
        )

        XCTAssertEqual(item.projectID, 0)
        XCTAssertEqual(item.fileName, "empty.jar")
    }

    func testSelectedResourcesResult_empty() {
        let result = ModPackExporter.SelectedResourcesResult(
            manifest: .modrinth([]),
            filesToCopy: [],
        )

        guard case let .modrinth(files) = result.manifest else {
            XCTFail("Expected Modrinth manifest")
            return
        }
        XCTAssertTrue(files.isEmpty)
        XCTAssertTrue(result.filesToCopy.isEmpty)
    }

    func testSelectedResourcesResult_withFiles() {
        let indexFile = ModrinthIndexFile(
            path: "mods/test.jar",
            hashes: ModrinthIndexFileHashes(from: ["sha1": "abc"]),
            downloads: [],
            fileSize: 0,
        )
        let copyItem: (file: URL, relativePath: String) = (
            file: URL(fileURLWithPath: "/tmp/config.json"),
            relativePath: "config",
        )

        let result = ModPackExporter.SelectedResourcesResult(
            manifest: .modrinth([indexFile]),
            filesToCopy: [copyItem],
        )

        guard case let .modrinth(files) = result.manifest else {
            XCTFail("Expected Modrinth manifest")
            return
        }
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(result.filesToCopy.count, 1)
        XCTAssertEqual(result.filesToCopy.first?.relativePath, "config")
    }

    func testCopyFilesParams_empty() {
        let params = ModPackExporter.CopyFilesParams(
            filesToCopy: [],
            overridesDir: URL(fileURLWithPath: "/tmp/overrides"),
        )

        XCTAssertTrue(params.filesToCopy.isEmpty)
    }

    func testIndexBuildParams_allFields() {
        let gameInfo = GameVersionInfo(
            gameName: "Test",
            gameIcon: "icon.png",
            gameVersion: "1.20.1",
            modVersion: "0.14.21",
            assetIndex: "17",
            modLoader: "fabric",
            mainClass: "net.minecraft.client.main.Main",
        )
        let params = ModPackExporter.IndexBuildParams(
            gameInfo: gameInfo,
            modPackName: "Pack",
            modPackVersion: "1.0",
            summary: "Test",
            manifest: .modrinth([]),
        )

        XCTAssertEqual(params.modPackName, "Pack")
        XCTAssertEqual(params.gameInfo.gameVersion, "1.20.1")
    }
}
