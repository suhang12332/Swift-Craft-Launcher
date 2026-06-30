//
//  ModPackExporterStructsTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ModPackExporterStructsTests: XCTestCase {
    func testExportResult_success() {
        let url = URL(fileURLWithPath: "/tmp/test.mrpack")
        let result = ModPackExporter.ExportResult(
            success: true,
            outputPath: url,
            error: nil,
            message: "OK",
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.outputPath, url)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.message, "OK")
    }

    func testExportResult_failure() {
        let error = NSError(domain: "test", code: 1, userInfo: nil)
        let result = ModPackExporter.ExportResult(
            success: false,
            outputPath: nil,
            error: error,
            message: "Failed",
        )

        XCTAssertFalse(result.success)
        XCTAssertNil(result.outputPath)
        XCTAssertNotNil(result.error)
        XCTAssertEqual(result.message, "Failed")
    }

    func testExportProgress_defaultValues() {
        let progress = ModPackExporter.ExportProgress()

        XCTAssertNil(progress.scanProgress)
        XCTAssertNil(progress.copyProgress)
    }

    func testExportProgress_withScanProgress() {
        let scanItem = ModPackExporter.ExportProgress.ProgressItem(
            title: "Scanning",
            progress: 0.5,
            currentFile: "mod.jar",
            completed: 5,
            total: 10,
        )
        let progress = ModPackExporter.ExportProgress(scanProgress: scanItem, copyProgress: nil)

        XCTAssertNotNil(progress.scanProgress)
        XCTAssertNil(progress.copyProgress)
        XCTAssertEqual(progress.scanProgress?.title, "Scanning")
        XCTAssertEqual(progress.scanProgress?.progress, 0.5)
        XCTAssertEqual(progress.scanProgress?.currentFile, "mod.jar")
        XCTAssertEqual(progress.scanProgress?.completed, 5)
        XCTAssertEqual(progress.scanProgress?.total, 10)
    }

    func testExportProgress_withCopyProgress() {
        let copyItem = ModPackExporter.ExportProgress.ProgressItem(
            title: "Copying",
            progress: 1.0,
            currentFile: "done.jar",
            completed: 3,
            total: 3,
        )
        let progress = ModPackExporter.ExportProgress(scanProgress: nil, copyProgress: copyItem)

        XCTAssertNil(progress.scanProgress)
        XCTAssertNotNil(progress.copyProgress)
        XCTAssertEqual(progress.copyProgress?.title, "Copying")
        XCTAssertEqual(progress.copyProgress?.progress, 1.0)
    }

    func testCurseForgeModListItem_init() {
        let item = ModPackExporter.CurseForgeModListItem(
            projectID: 123,
            fileID: 456,
            fileName: "mod.jar",
            projectName: "TestMod",
            authorsText: "Author1",
        )

        XCTAssertEqual(item.projectID, 123)
        XCTAssertEqual(item.fileID, 456)
        XCTAssertEqual(item.fileName, "mod.jar")
        XCTAssertEqual(item.projectName, "TestMod")
        XCTAssertEqual(item.authorsText, "Author1")
    }

    func testCurseForgeModListItem_nilOptionals() {
        let item = ModPackExporter.CurseForgeModListItem(
            projectID: 1,
            fileID: 2,
            fileName: "f.jar",
            projectName: nil,
            authorsText: nil,
        )

        XCTAssertNil(item.projectName)
        XCTAssertNil(item.authorsText)
    }

    func testResolveSelectedFiles_emptyInput() {
        let result = ModPackExporter.resolveSelectedFiles(from: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testResolveSelectedFiles_singleFile() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_resolve_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("test.jar")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data("test".utf8))

        let result = ModPackExporter.resolveSelectedFiles(from: [fileURL])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.lastPathComponent, "test.jar")
    }

    func testResolveSelectedFiles_directoryExpands() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_resolve_dir_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file1 = tempDir.appendingPathComponent("a.jar")
        let file2 = tempDir.appendingPathComponent("b.jar")
        FileManager.default.createFile(atPath: file1.path, contents: Data("a".utf8))
        FileManager.default.createFile(atPath: file2.path, contents: Data("b".utf8))

        let result = ModPackExporter.resolveSelectedFiles(from: [tempDir])
        XCTAssertEqual(result.count, 2)
    }

    func testProgressItem_allProperties() {
        let item = ModPackExporter.ExportProgress.ProgressItem(
            title: "Title",
            progress: 0.75,
            currentFile: "file.jar",
            completed: 75,
            total: 100,
        )

        XCTAssertEqual(item.title, "Title")
        XCTAssertEqual(item.progress, 0.75)
        XCTAssertEqual(item.currentFile, "file.jar")
        XCTAssertEqual(item.completed, 75)
        XCTAssertEqual(item.total, 100)
    }
}
