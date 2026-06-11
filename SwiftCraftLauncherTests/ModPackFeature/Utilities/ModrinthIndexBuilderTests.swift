import XCTest
@testable import SwiftCraftLauncher

final class ModrinthIndexBuilderTests: XCTestCase {

    private func makeGameInfo(
        gameVersion: String = "1.20.1",
        modLoader: String = "fabric",
        modVersion: String = "0.14.21"
    ) -> GameVersionInfo {
        GameVersionInfo(
            gameName: "TestGame",
            gameIcon: "icon.png",
            gameVersion: gameVersion,
            modVersion: modVersion,
            assetIndex: "17",
            modLoader: modLoader,
            mainClass: "net.minecraft.client.main.Main"
        )
    }

    private func makeFile(
        path: String = "mods/test.jar",
        sha1: String = "abc123"
    ) -> ModrinthIndexFile {
        ModrinthIndexFile(
            path: path,
            hashes: ModrinthIndexFileHashes(from: ["sha1": sha1]),
            downloads: ["https://example.com/test.jar"],
            fileSize: 1024
        )
    }

    func testBuild_fabric() async throws {
        let gameInfo = makeGameInfo(modLoader: "fabric", modVersion: "0.14.21")
        let files = [makeFile()]

        let json = try await ModrinthIndexBuilder.build(
            gameInfo: gameInfo,
            modPackName: "FabricPack",
            modPackVersion: "1.0",
            summary: "A fabric pack",
            files: files
        )

        XCTAssertTrue(json.contains("\"fabric-loader\""))
    }

    func testBuild_forge() async throws {
        let gameInfo = makeGameInfo(modLoader: "forge", modVersion: "47.2.0")

        let json = try await ModrinthIndexBuilder.build(
            gameInfo: gameInfo,
            modPackName: "ForgePack",
            modPackVersion: "2.0",
            summary: nil,
            files: []
        )

        XCTAssertTrue(json.contains("\"forge-loader\""))
    }

    func testBuild_neoforge() async throws {
        let gameInfo = makeGameInfo(modLoader: "neoforge", modVersion: "21.0.0")

        let json = try await ModrinthIndexBuilder.build(
            gameInfo: gameInfo,
            modPackName: "NeoPack",
            modPackVersion: "1.0",
            summary: nil,
            files: []
        )

        XCTAssertTrue(json.contains("\"neoforge-loader\""))
    }

    func testBuild_quilt() async throws {
        let gameInfo = makeGameInfo(modLoader: "quilt", modVersion: "0.22.0")

        let json = try await ModrinthIndexBuilder.build(
            gameInfo: gameInfo,
            modPackName: "QuiltPack",
            modPackVersion: "1.0",
            summary: nil,
            files: []
        )

        XCTAssertTrue(json.contains("\"quilt-loader\""))
    }

    func testBuild_vanilla() async throws {
        let gameInfo = makeGameInfo(modLoader: "vanilla", modVersion: "")

        let json = try await ModrinthIndexBuilder.build(
            gameInfo: gameInfo,
            modPackName: "VanillaPack",
            modPackVersion: "1.0",
            summary: nil,
            files: []
        )

        XCTAssertTrue(json.contains("\"dependencies\""))
    }
}
