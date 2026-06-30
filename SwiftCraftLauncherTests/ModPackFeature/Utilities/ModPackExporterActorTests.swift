//
//  ModPackExporterActorTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

@MainActor
final class ModPackExporterActorTests: XCTestCase {

    func testProcessedCounter_increment() async {
        let counter = ModPackExporter.ProcessedCounter()
        let count1 = await counter.increment()
        let count2 = await counter.increment()
        let count3 = await counter.increment()

        XCTAssertEqual(count1, 1)
        XCTAssertEqual(count2, 2)
        XCTAssertEqual(count3, 3)
    }

    func testCopyCounter_increment() async {
        let counter = ModPackExporter.CopyCounter(total: 10)
        let (count1, total1) = await counter.increment()
        let (count2, total2) = await counter.increment()

        XCTAssertEqual(count1, 1)
        XCTAssertEqual(total1, 10)
        XCTAssertEqual(count2, 2)
        XCTAssertEqual(total2, 10)
    }

    func testProgressUpdater_setCopyProgressTotal() async {
        let updater = ModPackExporter.ProgressUpdater()
        await updater.setCopyProgressTotal(20)

        let progress = await updater.getFullProgress()
        XCTAssertNotNil(progress.copyProgress)
        XCTAssertEqual(progress.copyProgress?.total, 20)
    }

    func testProgressUpdater_advanceScanProgress() async {
        let updater = ModPackExporter.ProgressUpdater()
        let progress = await updater.advanceScanProgress(processed: 5, total: 10, currentFile: "test.jar")

        XCTAssertEqual(progress.scanProgress?.completed, 5)
        XCTAssertEqual(progress.scanProgress?.total, 10)
        XCTAssertEqual(progress.scanProgress?.currentFile, "test.jar")
        if let p = progress.scanProgress?.progress {
            XCTAssertEqual(p, 0.5, accuracy: 0.001)
        } else {
            XCTFail("scanProgress.progress should not be nil")
        }
    }

    func testProgressUpdater_advanceCopyProgress() async {
        let updater = ModPackExporter.ProgressUpdater()
        let progress = await updater.advanceCopyProgress(processed: 3, total: 6, currentFile: "mod.jar")

        XCTAssertEqual(progress.copyProgress?.completed, 3)
        XCTAssertEqual(progress.copyProgress?.total, 6)
        if let p = progress.copyProgress?.progress {
            XCTAssertEqual(p, 0.5, accuracy: 0.001)
        } else {
            XCTFail("copyProgress.progress should not be nil")
        }
    }

    func testProgressUpdater_getFullProgress_empty() async {
        let updater = ModPackExporter.ProgressUpdater()
        let progress = await updater.getFullProgress()

        XCTAssertNil(progress.scanProgress)
        XCTAssertNil(progress.copyProgress)
    }
}
