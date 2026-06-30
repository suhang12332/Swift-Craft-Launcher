//
//  CurseForgeManifestModelTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher
import CFModrinthAdapterKit

final class CurseForgeManifestModelTests: XCTestCase {

    func testCurseForgeManifest_decodable() throws {
        let json = """
        {
            "minecraft": {
                "version": "1.20.1",
                "modLoaders": [
                    {"id": "forge-47.2.0", "primary": true}
                ]
            },
            "manifestType": "minecraftModpack",
            "manifestVersion": 1,
            "name": "Test Pack",
            "version": "1.0.0",
            "author": "TestAuthor",
            "files": [
                {"projectID": 100, "fileID": 200, "required": true}
            ],
            "overrides": "overrides"
        }
        """
        let manifest = try JSONDecoder().decode(CurseForgeManifest.self, from: Data(json.utf8))

        XCTAssertEqual(manifest.name, "Test Pack")
        XCTAssertEqual(manifest.version, "1.0.0")
        XCTAssertEqual(manifest.author, "TestAuthor")
        XCTAssertEqual(manifest.manifestType, "minecraftModpack")
        XCTAssertEqual(manifest.manifestVersion, 1)
        XCTAssertEqual(manifest.overrides, "overrides")
        XCTAssertEqual(manifest.minecraft.version, "1.20.1")
        XCTAssertEqual(manifest.minecraft.modLoaders.count, 1)
        XCTAssertEqual(manifest.files.count, 1)
    }

    func testCurseForgeManifest_nilVersion() throws {
        let json = """
        {
            "minecraft": {
                "version": "1.20.1",
                "modLoaders": []
            },
            "manifestType": "minecraftModpack",
            "manifestVersion": 1,
            "name": "No Version Pack",
            "files": []
        }
        """
        let manifest = try JSONDecoder().decode(CurseForgeManifest.self, from: Data(json.utf8))

        XCTAssertNil(manifest.version)
        XCTAssertNil(manifest.author)
        XCTAssertNil(manifest.overrides)
    }

    func testCurseForgeManifest_multipleModLoaders() throws {
        let json = """
        {
            "minecraft": {
                "version": "1.20.1",
                "modLoaders": [
                    {"id": "forge-47.2.0", "primary": true},
                    {"id": "fabric-0.14.21", "primary": false}
                ]
            },
            "manifestType": "minecraftModpack",
            "manifestVersion": 1,
            "name": "Multi Loader Pack",
            "files": []
        }
        """
        let manifest = try JSONDecoder().decode(CurseForgeManifest.self, from: Data(json.utf8))

        XCTAssertEqual(manifest.minecraft.modLoaders.count, 2)
        XCTAssertTrue(manifest.minecraft.modLoaders[0].primary)
        XCTAssertFalse(manifest.minecraft.modLoaders[1].primary)
    }

    func testCurseForgeManifest_multipleFiles() throws {
        let json = """
        {
            "minecraft": {
                "version": "1.20.1",
                "modLoaders": []
            },
            "manifestType": "minecraftModpack",
            "manifestVersion": 1,
            "name": "Multi File Pack",
            "files": [
                {"projectID": 1, "fileID": 10, "required": true},
                {"projectID": 2, "fileID": 20, "required": false},
                {"projectID": 3, "fileID": 30, "required": true}
            ]
        }
        """
        let manifest = try JSONDecoder().decode(CurseForgeManifest.self, from: Data(json.utf8))

        XCTAssertEqual(manifest.files.count, 3)
        XCTAssertEqual(manifest.files[0].projectID, 1)
        XCTAssertEqual(manifest.files[1].fileID, 20)
        XCTAssertTrue(manifest.files[2].required)
    }

    func testCurseForgeModLoader_primary() throws {
        let json = """
        {"id": "forge-47.2.0", "primary": true}
        """
        let loader = try JSONDecoder().decode(CurseForgeModLoader.self, from: Data(json.utf8))

        XCTAssertEqual(loader.id, "forge-47.2.0")
        XCTAssertTrue(loader.primary)
    }

    func testCurseForgeModLoader_notPrimary() throws {
        let json = """
        {"id": "fabric-0.14.21", "primary": false}
        """
        let loader = try JSONDecoder().decode(CurseForgeModLoader.self, from: Data(json.utf8))

        XCTAssertEqual(loader.id, "fabric-0.14.21")
        XCTAssertFalse(loader.primary)
    }

    func testCurseForgeManifestFile_decodable() throws {
        let json = """
        {"projectID": 12345, "fileID": 67890, "required": true}
        """
        let file = try JSONDecoder().decode(CurseForgeManifestFile.self, from: Data(json.utf8))

        XCTAssertEqual(file.projectID, 12345)
        XCTAssertEqual(file.fileID, 67890)
        XCTAssertTrue(file.required)
    }

    func testCurseForgeManifestFile_notRequired() throws {
        let json = """
        {"projectID": 1, "fileID": 2, "required": false}
        """
        let file = try JSONDecoder().decode(CurseForgeManifestFile.self, from: Data(json.utf8))

        XCTAssertFalse(file.required)
    }

    func testManifestFile_codable() throws {
        let original = CurseForgeManifestBuilder.ManifestFile(
            projectID: 100,
            fileID: 200,
            required: true,
            isLocked: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CurseForgeManifestBuilder.ManifestFile.self, from: data)

        XCTAssertEqual(decoded.projectID, 100)
        XCTAssertEqual(decoded.fileID, 200)
        XCTAssertTrue(decoded.required)
        XCTAssertFalse(decoded.isLocked)
    }

    func testManifestFile_allFields() throws {
        let original = CurseForgeManifestBuilder.ManifestFile(
            projectID: 999,
            fileID: 888,
            required: false,
            isLocked: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CurseForgeManifestBuilder.ManifestFile.self, from: data)

        XCTAssertEqual(decoded.projectID, 999)
        XCTAssertEqual(decoded.fileID, 888)
        XCTAssertFalse(decoded.required)
        XCTAssertTrue(decoded.isLocked)
    }
}
