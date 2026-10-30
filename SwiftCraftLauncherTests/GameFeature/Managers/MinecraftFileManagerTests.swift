//
//  MinecraftFileManagerTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class MinecraftFileManagerTests: XCTestCase {
    func testCalculateTotalFiles_excludesAssetIndex() throws {
        let manifest = try decodeManifest()
        let fileNameCount = MinecraftFileManager().calculateTotalFiles(manifest)

        // client.jar + logging config; the asset index is not part of file progress.
        XCTAssertEqual(fileNameCount, 2)
    }

    private func decodeManifest() throws -> MinecraftVersionManifest {
        let json = """
        {
            "arguments": {"game": [], "jvm": []},
            "assetIndex": {"id": "17", "sha1": "a", "size": 1, "totalSize": 2, "url": "https://e.com/i.json"},
            "assets": "17",
            "downloads": {"client": {"sha1": "b", "size": 3, "url": "https://e.com/c.jar"}},
            "id": "1.20.1",
            "javaVersion": {"component": "java-runtime", "majorVersion": 17},
            "libraries": [],
            "logging": {"client": {"argument": "", "file": {"id": "l", "sha1": "c", "size": 4, "url": "https://e.com/l.xml"}, "type": "t"}},
            "mainClass": "Main",
            "minimumLauncherVersion": 21,
            "releaseTime": "2023-01-01",
            "time": "2023-01-01",
            "type": "release"
        }
        """
        return try JSONDecoder().decode(MinecraftVersionManifest.self, from: Data(json.utf8))
    }
}
