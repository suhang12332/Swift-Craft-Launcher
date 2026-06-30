//
//  ModrinthIndexInfoExtendedTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class ModrinthIndexInfoExtendedTests: XCTestCase {

    private func makeFile(path: String = "mods/test.jar") -> ModrinthIndexFile {
        ModrinthIndexFile(
            path: path,
            hashes: ModrinthIndexFileHashes(from: ["sha1": "abc"]),
            downloads: [],
            fileSize: 1024
        )
    }

    func testInit_withAllParams() {
        let dep = ModrinthIndexProjectDependency(
            projectId: "proj1",
            versionId: "ver1",
            dependencyType: "required"
        )
        let file = makeFile()
        let info = ModrinthIndexInfo(
            gameVersion: "1.20.1",
            loaderType: "fabric",
            loaderVersion: "0.14.21",
            modPackName: "Test Pack",
            modPackVersion: "1.0.0",
            summary: "A test",
            files: [file],
            dependencies: [dep],
            source: .modrinth
        )

        XCTAssertEqual(info.gameVersion, "1.20.1")
        XCTAssertEqual(info.loaderType, "fabric")
        XCTAssertEqual(info.loaderVersion, "0.14.21")
        XCTAssertEqual(info.modPackName, "Test Pack")
        XCTAssertEqual(info.modPackVersion, "1.0.0")
        XCTAssertEqual(info.summary, "A test")
        XCTAssertEqual(info.files.count, 1)
        XCTAssertEqual(info.dependencies.count, 1)
        XCTAssertEqual(info.source, .modrinth)
    }

    func testInit_defaultSource() {
        let info = ModrinthIndexInfo(
            gameVersion: "1.20.1",
            loaderType: "forge",
            loaderVersion: "47.2.0",
            modPackName: "Pack",
            modPackVersion: "1.0",
            summary: nil,
            files: [],
            dependencies: []
        )

        XCTAssertEqual(info.source, .modrinth)
    }

    func testInit_curseforgeSource() {
        let info = ModrinthIndexInfo(
            gameVersion: "1.20.1",
            loaderType: "forge",
            loaderVersion: "47.2.0",
            modPackName: "CF Pack",
            modPackVersion: "1.0",
            summary: nil,
            files: [],
            dependencies: [],
            source: .curseforge
        )

        XCTAssertEqual(info.source, .curseforge)
    }

    func testInit_emptyDependencies() {
        let info = ModrinthIndexInfo(
            gameVersion: "1.20.1",
            loaderType: "vanilla",
            loaderVersion: "",
            modPackName: "Vanilla",
            modPackVersion: "1.0",
            summary: nil,
            files: [],
            dependencies: []
        )

        XCTAssertTrue(info.dependencies.isEmpty)
        XCTAssertTrue(info.files.isEmpty)
    }

    func testInit_multipleFilesAndDependencies() {
        let files = [
            makeFile(path: "mods/a.jar"),
            makeFile(path: "mods/b.jar"),
            makeFile(path: "mods/c.jar"),
        ]
        let deps = [
            ModrinthIndexProjectDependency(projectId: "p1", versionId: nil, dependencyType: "required"),
            ModrinthIndexProjectDependency(projectId: "p2", versionId: "v2", dependencyType: "optional"),
        ]
        let info = ModrinthIndexInfo(
            gameVersion: "1.20.1",
            loaderType: "fabric",
            loaderVersion: "0.14.21",
            modPackName: "Big Pack",
            modPackVersion: "2.0",
            summary: "Many mods",
            files: files,
            dependencies: deps,
            source: .modrinth
        )

        XCTAssertEqual(info.files.count, 3)
        XCTAssertEqual(info.dependencies.count, 2)
    }
}
