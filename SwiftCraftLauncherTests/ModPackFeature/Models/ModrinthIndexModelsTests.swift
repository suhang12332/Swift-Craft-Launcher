//
//  ModrinthIndexModelsTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class ModrinthIndexModelsExtendedTests: XCTestCase {

    func testModrinthIndex_codable_roundtrip() throws {
        let index = ModrinthIndex(
            formatVersion: 1,
            game: "minecraft",
            versionId: "1.0.0",
            name: "Test Pack",
            summary: "A test pack",
            files: [],
            dependencies: ModrinthIndexDependencies(
                minecraft: "1.20.1",
                forgeLoader: nil,
                fabricLoader: "0.14.0",
                quiltLoader: nil,
                neoforgeLoader: nil,
                forge: nil,
                fabric: nil,
                quilt: nil,
                neoforge: nil,
                dependencies: nil
            )
        )
        let data = try JSONEncoder().encode(index)
        let decoded = try JSONDecoder().decode(ModrinthIndex.self, from: data)
        XCTAssertEqual(decoded.formatVersion, 1)
        XCTAssertEqual(decoded.game, "minecraft")
        XCTAssertEqual(decoded.versionId, "1.0.0")
        XCTAssertEqual(decoded.name, "Test Pack")
        XCTAssertEqual(decoded.summary, "A test pack")
        XCTAssertTrue(decoded.files.isEmpty)
    }

    func testModrinthIndex_nilSummary() throws {
        let index = ModrinthIndex(
            formatVersion: 1,
            game: "minecraft",
            versionId: "1.0.0",
            name: "Test",
            summary: nil,
            files: [],
            dependencies: ModrinthIndexDependencies(
                minecraft: "1.20.1",
                forgeLoader: nil,
                fabricLoader: nil,
                quiltLoader: nil,
                neoforgeLoader: nil,
                forge: nil,
                fabric: nil,
                quilt: nil,
                neoforge: nil,
                dependencies: nil
            )
        )
        let data = try JSONEncoder().encode(index)
        let decoded = try JSONDecoder().decode(ModrinthIndex.self, from: data)
        XCTAssertNil(decoded.summary)
    }

    func testModrinthIndexDependencies_codable() throws {
        let deps = ModrinthIndexDependencies(
            minecraft: "1.20.1",
            forgeLoader: "47.2.0",
            fabricLoader: nil,
            quiltLoader: nil,
            neoforgeLoader: nil,
            forge: "47.2.0",
            fabric: nil,
            quilt: nil,
            neoforge: nil,
            dependencies: nil
        )
        let data = try JSONEncoder().encode(deps)
        let decoded = try JSONDecoder().decode(ModrinthIndexDependencies.self, from: data)
        XCTAssertEqual(decoded.minecraft, "1.20.1")
        XCTAssertEqual(decoded.forgeLoader, "47.2.0")
        XCTAssertNil(decoded.fabricLoader)
        XCTAssertEqual(decoded.forge, "47.2.0")
    }

    func testModrinthIndexDependencies_codingKeys() throws {
        let json = Data("""
        {
            "minecraft": "1.20.1",
            "forge-loader": "47.2.0",
            "fabric-loader": "0.14.0"
        }
        """.utf8)
        let decoded = try JSONDecoder().decode(ModrinthIndexDependencies.self, from: json)
        XCTAssertEqual(decoded.forgeLoader, "47.2.0")
        XCTAssertEqual(decoded.fabricLoader, "0.14.0")
    }

    func testModrinthIndexProjectDependency_codable() throws {
        let dep = ModrinthIndexProjectDependency(
            projectId: "abc123",
            versionId: "def456",
            dependencyType: "required"
        )
        let data = try JSONEncoder().encode(dep)
        let decoded = try JSONDecoder().decode(ModrinthIndexProjectDependency.self, from: data)
        XCTAssertEqual(decoded.projectId, "abc123")
        XCTAssertEqual(decoded.versionId, "def456")
        XCTAssertEqual(decoded.dependencyType, "required")
    }

    func testModrinthIndexProjectDependency_codingKeys() throws {
        let json = Data("""
        {
            "project_id": "abc",
            "version_id": "def",
            "dependency_type": "optional"
        }
        """.utf8)
        let decoded = try JSONDecoder().decode(ModrinthIndexProjectDependency.self, from: json)
        XCTAssertEqual(decoded.projectId, "abc")
        XCTAssertEqual(decoded.versionId, "def")
        XCTAssertEqual(decoded.dependencyType, "optional")
    }

    func testModrinthIndexFileEnv_codable() throws {
        let env = ModrinthIndexFileEnv(client: "required", server: "optional")
        let data = try JSONEncoder().encode(env)
        let decoded = try JSONDecoder().decode(ModrinthIndexFileEnv.self, from: data)
        XCTAssertEqual(decoded.client, "required")
        XCTAssertEqual(decoded.server, "optional")
    }

    func testModrinthIndexFileEnv_nilValues() throws {
        let env = ModrinthIndexFileEnv(client: nil, server: nil)
        let data = try JSONEncoder().encode(env)
        let decoded = try JSONDecoder().decode(ModrinthIndexFileEnv.self, from: data)
        XCTAssertNil(decoded.client)
        XCTAssertNil(decoded.server)
    }

    func testFileSource_rawValues() {
        XCTAssertEqual(FileSource.modrinth.rawValue, "modrinth")
        XCTAssertEqual(FileSource.curseforge.rawValue, "curseforge")
    }

    func testFileSource_codable() throws {
        let source = FileSource.modrinth
        let data = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(FileSource.self, from: data)
        XCTAssertEqual(decoded, .modrinth)
    }

    func testModrinthIndexFileHashes_subscript_sha1() {
        let hashes = ModrinthIndexFileHashes(from: ["sha1": "abc123", "sha512": "def456"])
        XCTAssertEqual(hashes["sha1"], "abc123")
    }

    func testModrinthIndexFileHashes_subscript_sha512() {
        let hashes = ModrinthIndexFileHashes(from: ["sha1": "abc123", "sha512": "def456"])
        XCTAssertEqual(hashes["sha512"], "def456")
    }

    func testModrinthIndexFileHashes_subscript_other() {
        let hashes = ModrinthIndexFileHashes(from: ["sha1": "abc", "md5": "xyz"])
        XCTAssertEqual(hashes["md5"], "xyz")
    }

    func testModrinthIndexFileHashes_subscript_unknown() {
        let hashes = ModrinthIndexFileHashes(from: ["sha1": "abc"])
        XCTAssertNil(hashes["unknown"])
    }

    func testModrinthIndexFile_init_withHashes() {
        let hashes = ModrinthIndexFileHashes(from: ["sha1": "abc"])
        let file = ModrinthIndexFile(
            path: "mods/test.jar",
            hashes: hashes,
            downloads: ["https://example.com/test.jar"],
            fileSize: 1024
        )
        XCTAssertEqual(file.path, "mods/test.jar")
        XCTAssertEqual(file.hashes.sha1, "abc")
        XCTAssertEqual(file.fileSize, 1024)
        XCTAssertEqual(file.downloads.count, 1)
    }

    func testModrinthIndexFile_codable_roundtrip() throws {
        let hashes = ModrinthIndexFileHashes(from: ["sha1": "abc", "sha512": "def"])
        let file = ModrinthIndexFile(
            path: "mods/test.jar",
            hashes: hashes,
            downloads: ["https://example.com/test.jar"],
            fileSize: 1024,
            env: ModrinthIndexFileEnv(client: "required", server: nil),
            source: .modrinth,
            curseForgeProjectId: 123,
            curseForgeFileId: 456
        )
        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(ModrinthIndexFile.self, from: data)
        XCTAssertEqual(decoded.path, "mods/test.jar")
        XCTAssertEqual(decoded.fileSize, 1024)
        XCTAssertEqual(decoded.curseForgeProjectId, 123)
        XCTAssertEqual(decoded.curseForgeFileId, 456)
    }

    func testModrinthIndexInfo_init() {
        let info = ModrinthIndexInfo(
            gameVersion: "1.20.1",
            loaderType: "fabric",
            loaderVersion: "0.14.0",
            modPackName: "Test Pack",
            modPackVersion: "1.0",
            summary: "A test",
            files: [],
            dependencies: [],
            source: .modrinth
        )
        XCTAssertEqual(info.gameVersion, "1.20.1")
        XCTAssertEqual(info.loaderType, "fabric")
        XCTAssertEqual(info.source, .modrinth)
    }

    func testModrinthIndexInfo_defaultSource() {
        let info = ModrinthIndexInfo(
            gameVersion: "1.20.1",
            loaderType: "forge",
            loaderVersion: "47.2.0",
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: [],
            dependencies: []
        )
        XCTAssertEqual(info.source, .modrinth)
    }
}
