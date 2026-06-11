import XCTest
@testable import SwiftCraftLauncher

@MainActor
final class DownloadStateExtendedTests: XCTestCase {

    // MARK: - calculateProgress edge cases

    func testUpdateProgress_zeroTotal() {
        let state = DownloadState()
        state.startDownload(coreTotalFiles: 0, resourcesTotalFiles: 0)

        state.updateProgress(fileName: "file", completed: 5, total: 0, type: .core)

        XCTAssertEqual(state.coreProgress, 0)
        XCTAssertEqual(state.coreCompletedFiles, 5)
    }

    func testUpdateProgress_completedExceedsTotal() {
        let state = DownloadState()
        state.startDownload(coreTotalFiles: 10, resourcesTotalFiles: 0)

        state.updateProgress(fileName: "file", completed: 15, total: 10, type: .core)

        XCTAssertEqual(state.coreProgress, 1.0, accuracy: 0.001)
        XCTAssertEqual(state.coreCompletedFiles, 15)
    }

    func testUpdateProgress_negativeCompleted() {
        let state = DownloadState()
        state.startDownload(coreTotalFiles: 10, resourcesTotalFiles: 0)

        state.updateProgress(fileName: "file", completed: -1, total: 10, type: .core)

        XCTAssertEqual(state.coreProgress, 0.0, accuracy: 0.001)
    }

    func testUpdateProgress_zeroCompleted() {
        let state = DownloadState()
        state.startDownload(coreTotalFiles: 10, resourcesTotalFiles: 0)

        state.updateProgress(fileName: "file", completed: 0, total: 10, type: .core)

        XCTAssertEqual(state.coreProgress, 0.0, accuracy: 0.001)
        XCTAssertEqual(state.coreCompletedFiles, 0)
    }

    func testUpdateProgress_exactHalf() {
        let state = DownloadState()
        state.startDownload(coreTotalFiles: 10, resourcesTotalFiles: 0)

        state.updateProgress(fileName: "file", completed: 5, total: 10, type: .core)

        XCTAssertEqual(state.coreProgress, 0.5, accuracy: 0.001)
    }

    func testUpdateProgress_complete() {
        let state = DownloadState()
        state.startDownload(coreTotalFiles: 10, resourcesTotalFiles: 0)

        state.updateProgress(fileName: "file", completed: 10, total: 10, type: .core)

        XCTAssertEqual(state.coreProgress, 1.0, accuracy: 0.001)
    }

    func testReset_afterProgress() {
        let state = DownloadState()
        state.startDownload(coreTotalFiles: 10, resourcesTotalFiles: 5)
        state.updateProgress(fileName: "a.jar", completed: 5, total: 10, type: .core)
        state.updateProgress(fileName: "b.jar", completed: 3, total: 5, type: .resources)
        state.cancel()

        state.reset()

        XCTAssertEqual(state.coreProgress, 0)
        XCTAssertEqual(state.resourcesProgress, 0)
        XCTAssertEqual(state.coreCompletedFiles, 0)
        XCTAssertEqual(state.resourcesCompletedFiles, 0)
        XCTAssertFalse(state.isCancelled)
        XCTAssertFalse(state.isDownloading)
        XCTAssertEqual(state.currentCoreFile, "")
        XCTAssertEqual(state.currentResourceFile, "")
    }

    // MARK: - startDownload overwrites previous state

    func testStartDownload_overwritesPreviousState() {
        let state = DownloadState()
        state.startDownload(coreTotalFiles: 10, resourcesTotalFiles: 5)
        state.updateProgress(fileName: "old.jar", completed: 5, total: 10, type: .core)

        state.startDownload(coreTotalFiles: 20, resourcesTotalFiles: 10)

        XCTAssertEqual(state.coreTotalFiles, 20)
        XCTAssertEqual(state.resourcesTotalFiles, 10)
        XCTAssertEqual(state.coreCompletedFiles, 0)
        XCTAssertEqual(state.coreProgress, 0)
    }
}
