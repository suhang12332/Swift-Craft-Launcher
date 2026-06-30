//
//  ModrinthIndexBuilderExtendedTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ModrinthIndexBuilderExtendedTests: XCTestCase {
    private func makeGameInfo(
        gameVersion: String = "1.20.1",
        modLoader: String = "fabric",
        modVersion: String = "0.14.21",
    ) -> GameVersionInfo {
        GameVersionInfo(
            gameName: "TestGame",
            gameIcon: "icon.png",
            gameVersion: gameVersion,
            modVersion: modVersion,
            assetIndex: "17",
            modLoader: modLoader,
            mainClass: "net.minecraft.client.main.Main",
        )
    }

    private func makeFile(
        path: String = "mods/test.jar",
        sha1: String = "abc123",
        sha512: String = "def456",
    ) -> ModrinthIndexFile {
        ModrinthIndexFile(
            path: path,
            hashes: ModrinthIndexFileHashes(from: ["sha1": sha1, "sha512": sha512]),
            downloads: ["https://example.com/test.jar"],
            fileSize: 1024,
            env: ModrinthIndexFileEnv(client: "required", server: nil),
        )
    }

    func testBuild_jsonHasFormatVersion() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: [],
        )

        XCTAssertTrue(json.contains("\"formatVersion\""))
        XCTAssertTrue(json.contains("1"))
    }

    func testBuild_jsonHasGameField() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: [],
        )

        XCTAssertTrue(json.contains("\"game\""))
        XCTAssertTrue(json.contains("\"minecraft\""))
    }

    func testBuild_jsonHasNameAndVersion() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "My Pack",
            modPackVersion: "3.2.1",
            summary: nil,
            files: [],
        )

        XCTAssertTrue(json.contains("My Pack"))
        XCTAssertTrue(json.contains("3.2.1"))
    }

    func testBuild_jsonWithSummary() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: "This is a test pack",
            files: [],
        )

        XCTAssertTrue(json.contains("This is a test pack"))
    }

    func testBuild_jsonWithoutSummary() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: [],
        )

        XCTAssertFalse(json.contains("summary"))
    }

    func testBuild_jsonContainsFileHashes() async throws {
        let files = [makeFile(sha1: "sha1val", sha512: "sha512val")]
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: files,
        )

        XCTAssertTrue(json.contains("sha1val"))
        XCTAssertTrue(json.contains("sha512val"))
    }

    func testBuild_jsonContainsFileDownloads() async throws {
        let file = ModrinthIndexFile(
            path: "mods/test.jar",
            hashes: ModrinthIndexFileHashes(from: ["sha1": "abc"]),
            downloads: ["https://cdn.example.com/mod.jar"],
            fileSize: 1024,
        )
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: [file],
        )

        XCTAssertTrue(json.contains("cdn.example.com"))
        XCTAssertTrue(json.contains("mod.jar"))
    }

    func testBuild_jsonContainsFileSize() async throws {
        let file = ModrinthIndexFile(
            path: "mods/test.jar",
            hashes: ModrinthIndexFileHashes(from: ["sha1": "abc"]),
            downloads: [],
            fileSize: 9999,
        )
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: [file],
        )

        XCTAssertTrue(json.contains("9999"))
    }

    func testBuild_jsonContainsFileEnv() async throws {
        let files = [makeFile()]
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: files,
        )

        XCTAssertTrue(json.contains("\"env\""))
        XCTAssertTrue(json.contains("\"client\""))
        XCTAssertTrue(json.contains("\"required\""))
    }

    func testBuild_jsonMultipleFiles() async throws {
        let files = [
            makeFile(path: "mods/a.jar", sha1: "hash_a"),
            makeFile(path: "mods/b.jar", sha1: "hash_b"),
            makeFile(path: "resourcepacks/pack.zip", sha1: "hash_c"),
        ]
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "MultiFile",
            modPackVersion: "1.0",
            summary: nil,
            files: files,
        )

        XCTAssertTrue(json.contains("hash_a"))
        XCTAssertTrue(json.contains("hash_b"))
        XCTAssertTrue(json.contains("hash_c"))
    }

    func testBuild_fabricDependencies() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(modLoader: "fabric", modVersion: "0.15.0"),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: [],
        )

        XCTAssertTrue(json.contains("\"fabric-loader\""))
        XCTAssertTrue(json.contains("0.15.0"))
    }

    func testBuild_forgeDependencies() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(modLoader: "forge", modVersion: "47.3.0"),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: [],
        )

        XCTAssertTrue(json.contains("\"forge-loader\""))
        XCTAssertTrue(json.contains("47.3.0"))
    }

    func testBuild_neoforgeDependencies() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(modLoader: "neoforge", modVersion: "21.1.0"),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: [],
        )

        XCTAssertTrue(json.contains("\"neoforge-loader\""))
        XCTAssertTrue(json.contains("21.1.0"))
    }

    func testBuild_quiltDependencies() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(modLoader: "quilt", modVersion: "0.23.0"),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: [],
        )

        XCTAssertTrue(json.contains("\"quilt-loader\""))
        XCTAssertTrue(json.contains("0.23.0"))
    }

    func testBuild_vanillaDependencies_noLoaderKey() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(modLoader: "vanilla", modVersion: ""),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: [],
        )

        XCTAssertTrue(json.contains("\"minecraft\""))
        XCTAssertFalse(json.contains("\"forge-loader\""))
        XCTAssertFalse(json.contains("\"fabric-loader\""))
    }

    func testBuild_jsonHasDependenciesSection() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: [],
        )

        XCTAssertTrue(json.contains("\"dependencies\""))
    }
}
