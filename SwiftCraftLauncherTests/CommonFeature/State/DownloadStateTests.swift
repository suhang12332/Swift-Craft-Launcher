//
//  DownloadStateTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

@MainActor
final class DownloadStateTests: XCTestCase {

    func testReset_clearsAllProperties() {
        let state = DownloadState()
        state.isDownloading = true
        state.coreProgress = 0.5
        state.resourcesProgress = 0.3
        state.currentCoreFile = "test.jar"
        state.currentResourceFile = "mod.jar"
        state.coreTotalFiles = 10
        state.resourcesTotalFiles = 5
        state.coreCompletedFiles = 5
        state.resourcesCompletedFiles = 2
        state.isCancelled = true

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

    func testStartDownload_setsProperties() {
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

    func testCancel_setsIsCancelled() {
        let state = DownloadState()
        state.startDownload(coreTotalFiles: 10, resourcesTotalFiles: 5)

        state.cancel()

        XCTAssertTrue(state.isCancelled)
    }

    func testUpdateProgress_core() {
        let state = DownloadState()
        state.startDownload(coreTotalFiles: 10, resourcesTotalFiles: 5)

        state.updateProgress(fileName: "client.jar", completed: 5, total: 10, type: .core)

        XCTAssertEqual(state.currentCoreFile, "client.jar")
        XCTAssertEqual(state.coreCompletedFiles, 5)
        XCTAssertEqual(state.coreTotalFiles, 10)
        XCTAssertEqual(state.coreProgress, 0.5, accuracy: 0.001)
    }

    func testUpdateProgress_resources() {
        let state = DownloadState()
        state.startDownload(coreTotalFiles: 10, resourcesTotalFiles: 5)

        state.updateProgress(fileName: "mod.jar", completed: 3, total: 5, type: .resources)

        XCTAssertEqual(state.currentResourceFile, "mod.jar")
        XCTAssertEqual(state.resourcesCompletedFiles, 3)
        XCTAssertEqual(state.resourcesTotalFiles, 5)
        XCTAssertEqual(state.resourcesProgress, 0.6, accuracy: 0.001)
    }

    func testDefaultValues() {
        let state = DownloadState()

        XCTAssertFalse(state.isDownloading)
        XCTAssertEqual(state.coreProgress, 0)
        XCTAssertEqual(state.resourcesProgress, 0)
        XCTAssertFalse(state.isCancelled)
    }
}
