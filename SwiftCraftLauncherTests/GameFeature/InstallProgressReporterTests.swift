//
//  InstallProgressReporterTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

@MainActor
final class InstallProgressReporterTests: XCTestCase {
    func testStart_initializesPhases() {
        let reporter = InstallProgressReporter()
        reporter.start(coreTotalFiles: 10, resourcesTotalFiles: 5)

        XCTAssertTrue(reporter.isDownloading)
        XCTAssertFalse(reporter.isCancelled)
        XCTAssertEqual(reporter.core.total, 10)
        XCTAssertEqual(reporter.resources.total, 5)
        XCTAssertEqual(reporter.core.progress, 0)
        XCTAssertEqual(reporter.resources.progress, 0)
    }

    func testUpdateProgress_tracksCoreAndResources() {
        let reporter = InstallProgressReporter()
        reporter.start(coreTotalFiles: 10, resourcesTotalFiles: 5)

        reporter.updateProgress(fileName: "client.jar", completed: 5, total: 10, type: .core)
        reporter.updateProgress(fileName: "asset", completed: 2, total: 5, type: .resources)

        XCTAssertEqual(reporter.core.currentFile, "client.jar")
        XCTAssertEqual(reporter.core.completed, 5)
        XCTAssertEqual(reporter.core.progress, 0.5, accuracy: 0.001)
        XCTAssertEqual(reporter.resources.currentFile, "asset")
        XCTAssertEqual(reporter.resources.completed, 2)
        XCTAssertEqual(reporter.resources.progress, 0.4, accuracy: 0.001)
    }

    func testUpdateLoader_tracksLoaderPhase() {
        let reporter = InstallProgressReporter()
        reporter.start(coreTotalFiles: 1, resourcesTotalFiles: 0)

        reporter.updateLoader(fileName: "fabric-loader.jar", completed: 3, total: 4)

        XCTAssertEqual(reporter.loader.currentFile, "fabric-loader.jar")
        XCTAssertEqual(reporter.loader.completed, 3)
        XCTAssertEqual(reporter.loader.total, 4)
        XCTAssertEqual(reporter.loader.progress, 0.75, accuracy: 0.001)
    }

    func testCancel_setsCancelled() {
        let reporter = InstallProgressReporter()
        reporter.start(coreTotalFiles: 1, resourcesTotalFiles: 0)
        reporter.cancel()

        XCTAssertTrue(reporter.isCancelled)
    }

    func testReset_clearsAllPhases() {
        let reporter = InstallProgressReporter()
        reporter.start(coreTotalFiles: 10, resourcesTotalFiles: 5)
        reporter.updateProgress(fileName: "client.jar", completed: 5, total: 10, type: .core)
        reporter.updateLoader(fileName: "loader.jar", completed: 1, total: 2)
        reporter.cancel()

        reporter.reset()

        XCTAssertFalse(reporter.isDownloading)
        XCTAssertFalse(reporter.isCancelled)
        XCTAssertEqual(reporter.core.progress, 0)
        XCTAssertEqual(reporter.resources.progress, 0)
        XCTAssertEqual(reporter.loader.progress, 0)
        XCTAssertEqual(reporter.core.currentFile, "")
        XCTAssertEqual(reporter.loader.currentFile, "")
    }

    func testUpdateProgress_zeroTotal_keepsProgressAtZero() {
        let reporter = InstallProgressReporter()
        reporter.start(coreTotalFiles: 0, resourcesTotalFiles: 0)

        reporter.updateProgress(fileName: "file", completed: 5, total: 0, type: .core)

        XCTAssertEqual(reporter.core.progress, 0)
        XCTAssertEqual(reporter.core.completed, 5)
    }
}
