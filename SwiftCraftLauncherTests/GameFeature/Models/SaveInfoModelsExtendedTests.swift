//
//  SaveInfoModelsExtendedTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class SaveInfoModelsExtendedTests: XCTestCase {
    func testWorldInfo_idFromPath() {
        let url = URL(fileURLWithPath: "/tmp/some deeply/nested/world_folder")
        let world = WorldInfo(name: "My World", path: url)

        XCTAssertEqual(world.id, "world_folder")
    }

    func testWorldInfo_differentPaths_differentIds() {
        let a = WorldInfo(name: "A", path: URL(fileURLWithPath: "/tmp/worldA"))
        let b = WorldInfo(name: "B", path: URL(fileURLWithPath: "/tmp/worldB"))

        XCTAssertNotEqual(a.id, b.id)
    }

    func testWorldInfo_equatable_differentNames() {
        let url = URL(fileURLWithPath: "/tmp/W")
        let a = WorldInfo(name: "A", path: url)
        let b = WorldInfo(name: "B", path: url)

        XCTAssertNotEqual(a, b)
    }

    func testScreenshotInfo_idFromPath() {
        let url = URL(fileURLWithPath: "/tmp/screenshots/2024-01-01_12.00.00.png")
        let screenshot = ScreenshotInfo(name: "2024-01-01_12.00.00.png", path: url)

        XCTAssertEqual(screenshot.id, "2024-01-01_12.00.00.png")
    }

    func testScreenshotInfo_equatable() {
        let url = URL(fileURLWithPath: "/tmp/s.png")
        let a = ScreenshotInfo(name: "s.png", path: url, fileSize: 100)
        let b = ScreenshotInfo(name: "s.png", path: url, fileSize: 100)

        XCTAssertEqual(a, b)
    }

    func testScreenshotInfo_equatable_differentSize() {
        let url = URL(fileURLWithPath: "/tmp/s.png")
        let a = ScreenshotInfo(name: "s.png", path: url, fileSize: 100)
        let b = ScreenshotInfo(name: "s.png", path: url, fileSize: 200)

        XCTAssertNotEqual(a, b)
    }

    func testScreenshotInfo_largeFileSize() {
        let url = URL(fileURLWithPath: "/tmp/large.png")
        let screenshot = ScreenshotInfo(name: "large.png", path: url, fileSize: Int64.max)

        XCTAssertEqual(screenshot.fileSize, Int64.max)
    }

    func testLogInfo_idFromPath() {
        let url = URL(fileURLWithPath: "/tmp/logs/crash-2024-01-01.log")
        let log = LogInfo(name: "crash-2024-01-01.log", path: url, isCrashLog: true)

        XCTAssertEqual(log.id, "crash-2024-01-01.log")
        XCTAssertTrue(log.isCrashLog)
    }

    func testLogInfo_equatable() {
        let url = URL(fileURLWithPath: "/tmp/log.log")
        let a = LogInfo(name: "log.log", path: url, fileSize: 1024, isCrashLog: true)
        let b = LogInfo(name: "log.log", path: url, fileSize: 1024, isCrashLog: true)

        XCTAssertEqual(a, b)
    }

    func testLogInfo_equatable_differentCrashLog() {
        let url = URL(fileURLWithPath: "/tmp/log.log")
        let a = LogInfo(name: "log.log", path: url, isCrashLog: true)
        let b = LogInfo(name: "log.log", path: url, isCrashLog: false)

        XCTAssertNotEqual(a, b)
    }

    func testLogInfo_createdDate_optional() {
        let url = URL(fileURLWithPath: "/tmp/log.log")
        let log = LogInfo(name: "log.log", path: url, createdDate: nil)

        XCTAssertNil(log.createdDate)
    }
}
