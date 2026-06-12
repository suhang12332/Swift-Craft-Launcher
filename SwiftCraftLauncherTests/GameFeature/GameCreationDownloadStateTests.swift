import XCTest
@testable import SwiftCraftLauncher

@MainActor
final class GameCreationDownloadStateTests: XCTestCase {

    func testInitialState() {
        let state = DownloadState()
        XCTAssertFalse(state.isDownloading)
        XCTAssertEqual(state.coreProgress, 0)
        XCTAssertEqual(state.resourcesProgress, 0)
        XCTAssertEqual(state.currentCoreFile, "")
        XCTAssertEqual(state.currentResourceFile, "")
        XCTAssertEqual(state.coreTotalFiles, 0)
        XCTAssertEqual(state.resourcesTotalFiles, 0)
        XCTAssertEqual(state.coreCompletedFiles, 0)
        XCTAssertEqual(state.resourcesCompletedFiles, 0)
        XCTAssertFalse(state.isCancelled)
    }

    func testStartDownload() {
        let state = DownloadState()
        state.startDownload(coreTotalFiles: 10, resourcesTotalFiles: 5)
        XCTAssertTrue(state.isDownloading)
        XCTAssertEqual(state.coreTotalFiles, 10)
        XCTAssertEqual(state.resourcesTotalFiles, 5)
        XCTAssertEqual(state.coreProgress, 0)
        XCTAssertEqual(state.resourcesProgress, 0)
        XCTAssertEqual(state.coreCompletedFiles, 0)
        XCTAssertEqual(state.resourcesCompletedFiles, 0)
        XCTAssertFalse(state.isCancelled)
    }

    func testCancel() {
        let state = DownloadState()
        state.startDownload(coreTotalFiles: 10, resourcesTotalFiles: 5)
        state.cancel()
        XCTAssertTrue(state.isCancelled)
    }

    func testReset_afterStart() {
        let state = DownloadState()
        state.startDownload(coreTotalFiles: 10, resourcesTotalFiles: 5)
        state.cancel()
        state.reset()
        XCTAssertFalse(state.isDownloading)
        XCTAssertEqual(state.coreProgress, 0)
        XCTAssertEqual(state.resourcesProgress, 0)
        XCTAssertEqual(state.currentCoreFile, "")
        XCTAssertEqual(state.currentResourceFile, "")
        XCTAssertEqual(state.coreTotalFiles, 0)
        XCTAssertEqual(state.resourcesTotalFiles, 0)
        XCTAssertEqual(state.coreCompletedFiles, 0)
        XCTAssertEqual(state.resourcesCompletedFiles, 0)
        XCTAssertFalse(state.isCancelled)
    }

    func testUpdateProgress_core() {
        let state = DownloadState()
        state.startDownload(coreTotalFiles: 10, resourcesTotalFiles: 0)
        state.updateProgress(fileName: "client.jar", completed: 5, total: 10, type: .core)
        XCTAssertEqual(state.currentCoreFile, "client.jar")
        XCTAssertEqual(state.coreCompletedFiles, 5)
        XCTAssertEqual(state.coreTotalFiles, 10)
        XCTAssertEqual(state.coreProgress, 0.5, accuracy: 0.001)
    }

    func testUpdateProgress_resources() {
        let state = DownloadState()
        state.startDownload(coreTotalFiles: 0, resourcesTotalFiles: 20)
        state.updateProgress(fileName: "assets.zip", completed: 10, total: 20, type: .resources)
        XCTAssertEqual(state.currentResourceFile, "assets.zip")
        XCTAssertEqual(state.resourcesCompletedFiles, 10)
        XCTAssertEqual(state.resourcesTotalFiles, 20)
        XCTAssertEqual(state.resourcesProgress, 0.5, accuracy: 0.001)
    }

    func testUpdateProgress_complete_core() {
        let state = DownloadState()
        state.startDownload(coreTotalFiles: 3, resourcesTotalFiles: 0)
        state.updateProgress(fileName: "client.jar", completed: 3, total: 3, type: .core)
        XCTAssertEqual(state.coreProgress, 1.0, accuracy: 0.001)
    }

    func testUpdateProgress_zeroTotal() {
        let state = DownloadState()
        state.startDownload(coreTotalFiles: 0, resourcesTotalFiles: 0)
        state.updateProgress(fileName: "file", completed: 0, total: 0, type: .core)
        XCTAssertEqual(state.coreProgress, 0)
    }

    func testMultipleStartDownload_resetsState() {
        let state = DownloadState()
        state.startDownload(coreTotalFiles: 10, resourcesTotalFiles: 5)
        state.updateProgress(fileName: "a.jar", completed: 5, total: 10, type: .core)
        state.startDownload(coreTotalFiles: 20, resourcesTotalFiles: 0)
        XCTAssertEqual(state.coreTotalFiles, 20)
        XCTAssertEqual(state.coreCompletedFiles, 0)
        XCTAssertEqual(state.coreProgress, 0)
    }
}
