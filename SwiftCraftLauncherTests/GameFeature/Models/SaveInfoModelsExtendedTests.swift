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

    func testWorldInfo_seed_optional() {
        let url = URL(fileURLWithPath: "/tmp/W")
        let world = WorldInfo(name: "W", path: url, seed: nil)
        XCTAssertNil(world.seed)
    }

    func testWorldInfo_seed_negativeValue() {
        let url = URL(fileURLWithPath: "/tmp/W")
        let world = WorldInfo(name: "W", path: url, seed: -12345)
        XCTAssertEqual(world.seed, -12345)
    }

    func testWorldInfo_seed_maxValue() {
        let url = URL(fileURLWithPath: "/tmp/W")
        let world = WorldInfo(name: "W", path: url, seed: Int64.max)
        XCTAssertEqual(world.seed, Int64.max)
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

    func testWorldDetailMetadata_init() {
        let url = URL(fileURLWithPath: "/tmp/World")
        let metadata = WorldDetailMetadata(
            levelName: "My World",
            folderName: "World",
            path: url,
            lastPlayed: Date(),
            gameMode: "survival",
            difficulty: "normal",
            hardcore: false,
            cheats: true,
            versionName: "1.20.1",
            versionId: 3700,
            dataVersion: 3700,
            seed: 12345,
            spawn: "0,64,0",
            time: 6000,
            dayTime: 6000,
            weather: "clear",
            worldBorder: "59999968",
            gameRules: ["doDaylightCycle", "doMobSpawning"],
        )

        XCTAssertEqual(metadata.levelName, "My World")
        XCTAssertEqual(metadata.folderName, "World")
        XCTAssertEqual(metadata.gameMode, "survival")
        XCTAssertEqual(metadata.difficulty, "normal")
        XCTAssertFalse(metadata.hardcore)
        XCTAssertTrue(metadata.cheats)
        XCTAssertEqual(metadata.versionName, "1.20.1")
        XCTAssertEqual(metadata.versionId, 3700)
        XCTAssertEqual(metadata.dataVersion, 3700)
        XCTAssertEqual(metadata.seed, 12345)
        XCTAssertEqual(metadata.spawn, "0,64,0")
        XCTAssertEqual(metadata.time, 6000)
        XCTAssertEqual(metadata.dayTime, 6000)
        XCTAssertEqual(metadata.weather, "clear")
        XCTAssertEqual(metadata.worldBorder, "59999968")
        XCTAssertEqual(metadata.gameRules?.count, 2)
    }

    func testWorldDetailMetadata_nilOptionals() {
        let url = URL(fileURLWithPath: "/tmp/World")
        let metadata = WorldDetailMetadata(
            levelName: "World",
            folderName: "World",
            path: url,
            lastPlayed: nil,
            gameMode: "survival",
            difficulty: "normal",
            hardcore: false,
            cheats: false,
            versionName: nil,
            versionId: nil,
            dataVersion: nil,
            seed: nil,
            spawn: nil,
            time: nil,
            dayTime: nil,
            weather: nil,
            worldBorder: nil,
            gameRules: nil,
        )

        XCTAssertNil(metadata.lastPlayed)
        XCTAssertNil(metadata.versionName)
        XCTAssertNil(metadata.versionId)
        XCTAssertNil(metadata.dataVersion)
        XCTAssertNil(metadata.seed)
        XCTAssertNil(metadata.spawn)
        XCTAssertNil(metadata.time)
        XCTAssertNil(metadata.dayTime)
        XCTAssertNil(metadata.weather)
        XCTAssertNil(metadata.worldBorder)
        XCTAssertNil(metadata.gameRules)
    }
}
