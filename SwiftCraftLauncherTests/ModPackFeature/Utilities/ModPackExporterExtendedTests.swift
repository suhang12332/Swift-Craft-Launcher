import XCTest
@testable import SwiftCraftLauncher

final class ModPackExporterExtendedTests: XCTestCase {

    // MARK: - ExportResult edge cases

    func testExportResult_successWithMessage() {
        let result = ModPackExporter.ExportResult(
            success: true,
            outputPath: URL(fileURLWithPath: "/tmp/pack.mrpack"),
            error: nil,
            message: "Export completed successfully"
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
            message: "导出失败: Disk full"
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
            message: "已取消"
        )

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.error is CancellationError)
        XCTAssertEqual(result.message, "已取消")
    }

    // MARK: - ExportProgress ProgressItem edge cases

    func testProgressItem_zeroProgress() {
        let item = ModPackExporter.ExportProgress.ProgressItem(
            title: "Start",
            progress: 0.0,
            currentFile: "",
            completed: 0,
            total: 100
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
            total: 100
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
            total: 10
        )
        let copy = ModPackExporter.ExportProgress.ProgressItem(
            title: "Copy",
            progress: 0.3,
            currentFile: "b.jar",
            completed: 3,
            total: 10
        )
        let progress = ModPackExporter.ExportProgress(scanProgress: scan, copyProgress: copy)

        XCTAssertNotNil(progress.scanProgress)
        XCTAssertNotNil(progress.copyProgress)
        XCTAssertEqual(progress.scanProgress?.completed, 5)
        XCTAssertEqual(progress.copyProgress?.completed, 3)
    }

    // MARK: - CurseForgeModListItem edge cases

    func testCurseForgeModListItem_allFields() {
        let item = ModPackExporter.CurseForgeModListItem(
            projectID: 999999,
            fileID: 888888,
            fileName: "awesome-mod-3.0.jar",
            projectName: "Awesome Mod",
            authorsText: "Author1, Author2"
        )

        XCTAssertEqual(item.projectID, 999999)
        XCTAssertEqual(item.fileID, 888888)
        XCTAssertEqual(item.fileName, "awesome-mod-3.0.jar")
        XCTAssertEqual(item.projectName, "Awesome Mod")
        XCTAssertEqual(item.authorsText, "Author1, Author2")
    }

    func testCurseForgeModListItem_zeroIds() {
        let item = ModPackExporter.CurseForgeModListItem(
            projectID: 0,
            fileID: 0,
            fileName: "empty.jar",
            projectName: nil,
            authorsText: nil
        )

        XCTAssertEqual(item.projectID, 0)
        XCTAssertEqual(item.fileID, 0)
        XCTAssertNil(item.projectName)
        XCTAssertNil(item.authorsText)
    }

    // MARK: - SelectedResourcesResult

    func testSelectedResourcesResult_empty() {
        let result = ModPackExporter.SelectedResourcesResult(
            indexFiles: [],
            curseForgeFiles: [],
            curseForgeModListItems: [],
            filesToCopy: []
        )

        XCTAssertTrue(result.indexFiles.isEmpty)
        XCTAssertTrue(result.curseForgeFiles.isEmpty)
        XCTAssertTrue(result.curseForgeModListItems.isEmpty)
        XCTAssertTrue(result.filesToCopy.isEmpty)
    }

    func testSelectedResourcesResult_withFiles() {
        let indexFile = ModrinthIndexFile(
            path: "mods/test.jar",
            hashes: ModrinthIndexFileHashes(from: ["sha1": "abc"]),
            downloads: [],
            fileSize: 0
        )
        let copyItem: (file: URL, relativePath: String) = (
            file: URL(fileURLWithPath: "/tmp/config.json"),
            relativePath: "config"
        )

        let result = ModPackExporter.SelectedResourcesResult(
            indexFiles: [indexFile],
            curseForgeFiles: [],
            curseForgeModListItems: [],
            filesToCopy: [copyItem]
        )

        XCTAssertEqual(result.indexFiles.count, 1)
        XCTAssertEqual(result.filesToCopy.count, 1)
        XCTAssertEqual(result.filesToCopy.first?.relativePath, "config")
    }

    // MARK: - CopyFilesParams

    func testCopyFilesParams_empty() {
        let params = ModPackExporter.CopyFilesParams(
            filesToCopy: [],
            overridesDir: URL(fileURLWithPath: "/tmp/overrides")
        )

        XCTAssertTrue(params.filesToCopy.isEmpty)
    }

    // MARK: - IndexBuildParams

    func testIndexBuildParams_allFields() {
        let gameInfo = GameVersionInfo(
            gameName: "Test",
            gameIcon: "icon.png",
            gameVersion: "1.20.1",
            modVersion: "0.14.21",
            assetIndex: "17",
            modLoader: "fabric",
            mainClass: "net.minecraft.client.main.Main"
        )
        let params = ModPackExporter.IndexBuildParams(
            gameInfo: gameInfo,
            modPackName: "Pack",
            modPackVersion: "1.0",
            summary: "Test",
            indexFiles: [],
            curseForgeFiles: [],
            curseForgeModListItems: [],
            exportFormat: .modrinth
        )

        XCTAssertEqual(params.modPackName, "Pack")
        XCTAssertEqual(params.exportFormat, .modrinth)
        XCTAssertEqual(params.gameInfo.gameVersion, "1.20.1")
    }
}
