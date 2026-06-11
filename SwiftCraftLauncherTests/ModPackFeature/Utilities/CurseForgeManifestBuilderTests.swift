import XCTest
@testable import SwiftCraftLauncher

final class CurseForgeManifestBuilderTests: XCTestCase {

    private func makeGameInfo(
        gameVersion: String = "1.20.1",
        modLoader: String = "forge",
        modVersion: String = "47.2.0"
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

    func testBuild_withFabric() throws {
        let gameInfo = makeGameInfo(modLoader: "fabric", modVersion: "0.14.21")

        let json = try CurseForgeManifestBuilder.build(
            gameInfo: gameInfo,
            modPackName: "FabricPack",
            modPackVersion: "1.0",
            files: []
        )

        XCTAssertTrue(json.contains("fabric-0.14.21"))
    }

    func testBuild_withQuilt() throws {
        let gameInfo = makeGameInfo(modLoader: "quilt", modVersion: "0.22.0")

        let json = try CurseForgeManifestBuilder.build(
            gameInfo: gameInfo,
            modPackName: "QuiltPack",
            modPackVersion: "1.0",
            files: []
        )

        XCTAssertTrue(json.contains("quilt-0.22.0"))
    }

    func testBuild_withNeoForge() throws {
        let gameInfo = makeGameInfo(modLoader: "neoforge", modVersion: "21.0.0")

        let json = try CurseForgeManifestBuilder.build(
            gameInfo: gameInfo,
            modPackName: "NeoForgePack",
            modPackVersion: "1.0",
            files: []
        )

        XCTAssertTrue(json.contains("neoforge-21.0.0"))
    }

    func testBuild_multipleFiles() throws {
        let gameInfo = makeGameInfo()
        let files = [
            CurseForgeManifestBuilder.ManifestFile(projectID: 1, fileID: 10, required: true, isLocked: false),
            CurseForgeManifestBuilder.ManifestFile(projectID: 2, fileID: 20, required: false, isLocked: true),
        ]

        let json = try CurseForgeManifestBuilder.build(
            gameInfo: gameInfo,
            modPackName: "MultiFile",
            modPackVersion: "1.0",
            files: files
        )

        XCTAssertTrue(json.contains("1"))
        XCTAssertTrue(json.contains("10"))
        XCTAssertTrue(json.contains("2"))
        XCTAssertTrue(json.contains("20"))
    }
}
