//
//  LitematicaModelsTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class LitematicaModelsTests: XCTestCase {
    func testLitematicaInfo_init_defaults() {
        let info = LitematicaInfo(
            name: "Test Build",
            path: URL(fileURLWithPath: "/tmp/test.litematic"),
        )
        XCTAssertEqual(info.name, "Test Build")
        XCTAssertEqual(info.id, "test.litematic")
        XCTAssertNil(info.createdDate)
    }

    func testLitematicaInfo_init_createdDate() {
        let date = Date()
        let info = LitematicaInfo(
            name: "My Build",
            path: URL(fileURLWithPath: "/tmp/build.litematic"),
            createdDate: date,
        )
        XCTAssertEqual(info.name, "My Build")
        XCTAssertEqual(info.createdDate, date)
    }

    func testLitematicaInfo_equatable() {
        let a = LitematicaInfo(name: "Test", path: URL(fileURLWithPath: "/tmp/a.litematic"))
        let b = LitematicaInfo(name: "Test", path: URL(fileURLWithPath: "/tmp/a.litematic"))
        XCTAssertEqual(a, b)
    }

    func testLitematicaInfo_idFromPath() {
        let info = LitematicaInfo(
            name: "Build",
            path: URL(fileURLWithPath: "/some/deep/path/MyProject.litematic"),
        )
        XCTAssertEqual(info.id, "MyProject.litematic")
    }

    func testLitematicMetadata_init() {
        let meta = LitematicMetadata(
            name: "Castle",
            author: "Builder",
            description: "A castle",
            timeCreated: 1_000_000,
            timeModified: 2_000_000,
            totalVolume: 100,
            totalBlocks: 80,
            enclosingSize: Size(x: 10, y: 10, z: 1),
            regionCount: 1,
        )
        XCTAssertEqual(meta.name, "Castle")
        XCTAssertEqual(meta.author, "Builder")
        XCTAssertEqual(meta.description, "A castle")
        XCTAssertEqual(meta.timeCreated, 1_000_000)
        XCTAssertEqual(meta.timeModified, 2_000_000)
        XCTAssertEqual(meta.totalVolume, 100)
        XCTAssertEqual(meta.totalBlocks, 80)
        XCTAssertEqual(meta.enclosingSize.x, 10)
        XCTAssertEqual(meta.regionCount, 1)
    }

    func testSize_init() {
        let size = Size(x: 10, y: 20, z: 30)
        XCTAssertEqual(size.x, 10)
        XCTAssertEqual(size.y, 20)
        XCTAssertEqual(size.z, 30)
    }
}
