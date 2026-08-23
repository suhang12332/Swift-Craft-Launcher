//
//  MMCIndexAdapterTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class MMCIndexAdapterTests: XCTestCase {
    private let adapter = MMCIndexAdapter()

    func testCanParse_withMmcPackJson() async throws {
        let directory = try await makeExtractedPackDirectory(
            packJsonName: "mmc_pack_fabric",
            hasInstanceCfg: false,
        )

        let result = await adapter.canParse(extractedPath: directory)
        XCTAssertTrue(result)
    }

    func testCanParse_withoutMmcPackJson() async throws {
        let directory = try TestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = await adapter.canParse(extractedPath: directory)
        XCTAssertFalse(result)
    }

    func testCanParse_withInstanceCfgOnly() async throws {
        let directory = try TestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let cfgURL = directory.appendingPathComponent("instance.cfg")
        try Data("name=Test".utf8).write(to: cfgURL)

        let result = await adapter.canParse(extractedPath: directory)
        XCTAssertFalse(result)
    }

    func testParse_fabricLoader() async throws {
        let directory = try await makeExtractedPackDirectory(
            packJsonName: "mmc_pack_fabric",
            hasInstanceCfg: false,
        )

        let result = await adapter.parseToModrinthIndexInfo(extractedPath: directory)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.gameVersion, "1.20.1")
        XCTAssertEqual(result?.loaderType, GameLoader.fabric.displayName)
        XCTAssertEqual(result?.loaderVersion, "0.14.21")
        XCTAssertEqual(result?.modPackName, "Fabric Test Pack")
        XCTAssertEqual(result?.modPackVersion, "1.0.0")
        XCTAssertEqual(result?.source, .mmc)
        XCTAssertTrue(result?.files.isEmpty ?? true)
        XCTAssertTrue(result?.dependencies.isEmpty ?? true)
    }

    func testParse_forgeLoader() async throws {
        let directory = try await makeExtractedPackDirectory(
            packJsonName: "mmc_pack_forge",
            hasInstanceCfg: false,
        )

        let result = await adapter.parseToModrinthIndexInfo(extractedPath: directory)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.loaderType, GameLoader.forge.displayName)
        XCTAssertEqual(result?.loaderVersion, "47.2.0")
    }

    func testParse_neoforgeLoader() async throws {
        let directory = try await makeExtractedPackDirectory(
            packJsonName: "mmc_pack_neoforge",
            hasInstanceCfg: false,
        )

        let result = await adapter.parseToModrinthIndexInfo(extractedPath: directory)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.loaderType, GameLoader.neoforge.displayName)
        XCTAssertEqual(result?.loaderVersion, "20.4.23-beta")
    }

    func testParse_readsNameFromInstanceCfg() async throws {
        let directory = try TestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let packJsonURL = TestSupport.fixtureURL(
            subdirectory: "Fixtures/mmc",
            name: "mmc_pack_fabric",
            extension: "json",
        )
        try FileManager.default.copyItem(at: packJsonURL, to: directory.appendingPathComponent("mmc-pack.json"))

        guard let cfgData = "[General]\nname=My MMC Modpack\niconKey=grass\n".data(using: .utf8) else {
            XCTFail("Failed to create cfg data")
            return
        }
        try cfgData.write(to: directory.appendingPathComponent("instance.cfg"))

        let result = await adapter.parseToModrinthIndexInfo(extractedPath: directory)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.modPackName, "My MMC Modpack")
    }

    func testParse_instanceCfgNameTakesPrecedenceOverPackJsonName() async throws {
        let directory = try TestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let packJsonURL = TestSupport.fixtureURL(
            subdirectory: "Fixtures/mmc",
            name: "mmc_pack_fabric",
            extension: "json",
        )
        try FileManager.default.copyItem(at: packJsonURL, to: directory.appendingPathComponent("mmc-pack.json"))

        guard let cfgData = "[General]\nname=Config Name\n".data(using: .utf8) else {
            XCTFail("Failed to create cfg data")
            return
        }
        try cfgData.write(to: directory.appendingPathComponent("instance.cfg"))

        let result = await adapter.parseToModrinthIndexInfo(extractedPath: directory)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.modPackName, "Config Name")
    }

    func testParse_missingMinecraftComponent_returnsNil() async throws {
        let directory = try TestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let packJson: [String: Any] = [
            "formatVersion": 1,
            "components": [
                ["uid": "net.fabricmc.fabric-loader", "version": "0.14.21"],
            ],
        ]
        let packJsonData = try JSONSerialization.data(withJSONObject: packJson)
        try packJsonData.write(to: directory.appendingPathComponent("mmc-pack.json"))

        let result = await adapter.parseToModrinthIndexInfo(extractedPath: directory)
        XCTAssertNil(result)
    }

    func testParse_vanillaWhenNoLoaderComponent() async throws {
        let directory = try TestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let packJson: [String: Any] = [
            "formatVersion": 1,
            "components": [
                ["uid": "net.minecraft", "version": "1.20.1"],
            ],
        ]
        let packJsonData = try JSONSerialization.data(withJSONObject: packJson)
        try packJsonData.write(to: directory.appendingPathComponent("mmc-pack.json"))

        let result = await adapter.parseToModrinthIndexInfo(extractedPath: directory)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.loaderType, GameLoader.vanilla.displayName)
        XCTAssertEqual(result?.loaderVersion, "unknown")
    }

    func testParse_invalidJSON_returnsNil() async throws {
        let directory = try TestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try Data("{".utf8).write(to: directory.appendingPathComponent("mmc-pack.json"))

        let result = await adapter.parseToModrinthIndexInfo(extractedPath: directory)
        XCTAssertNil(result)
    }

    func testParse_quiltLoader() async throws {
        let directory = try TestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let packJson: [String: Any] = [
            "formatVersion": 1,
            "components": [
                ["uid": "net.minecraft", "version": "1.20.1"],
                ["uid": "org.quiltmc.quilt-loader", "version": "0.19.0"],
            ],
        ]
        let packJsonData = try JSONSerialization.data(withJSONObject: packJson)
        try packJsonData.write(to: directory.appendingPathComponent("mmc-pack.json"))

        let result = await adapter.parseToModrinthIndexInfo(extractedPath: directory)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.loaderType, GameLoader.quilt.rawValue)
        XCTAssertEqual(result?.loaderVersion, "0.19.0")
    }

    private func makeExtractedPackDirectory(
        packJsonName: String,
        hasInstanceCfg: Bool,
    ) async throws -> URL {
        let directory = try TestSupport.makeTemporaryDirectory()
        let packJsonURL = TestSupport.fixtureURL(
            subdirectory: "Fixtures/mmc",
            name: packJsonName,
            extension: "json",
        )
        try FileManager.default.copyItem(at: packJsonURL, to: directory.appendingPathComponent("mmc-pack.json"))

        if hasInstanceCfg {
            let cfgURL = TestSupport.fixtureURL(
                subdirectory: "Fixtures/mmc",
                name: "instance",
                extension: "cfg",
            )
            try FileManager.default.copyItem(at: cfgURL, to: directory.appendingPathComponent("instance.cfg"))
        }

        return directory
    }
}
