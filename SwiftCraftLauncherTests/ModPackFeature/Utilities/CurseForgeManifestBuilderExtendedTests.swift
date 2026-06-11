import XCTest
@testable import SwiftCraftLauncher

final class CurseForgeManifestBuilderExtendedTests: XCTestCase {

    private func makeGameInfo(
        modLoader: String = "forge",
        modVersion: String = "47.2.0",
        gameVersion: String = "1.20.1"
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

    // MARK: - build modLoaders

    func testBuild_vanilla_noModLoaders() throws {
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(modLoader: "vanilla", modVersion: ""),
            modPackName: "Vanilla Pack",
            modPackVersion: "1.0",
            files: []
        )
        XCTAssertFalse(json.isEmpty)
        XCTAssertTrue(json.contains("Vanilla Pack"))
    }

    func testBuild_forge_includesModLoader() throws {
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(modLoader: "forge", modVersion: "47.2.0"),
            modPackName: "Forge Pack",
            modPackVersion: "1.0",
            files: []
        )
        XCTAssertTrue(json.contains("forge-47.2.0"))
    }

    func testBuild_fabric_includesModLoader() throws {
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(modLoader: "fabric", modVersion: "0.14.21"),
            modPackName: "Fabric Pack",
            modPackVersion: "1.0",
            files: []
        )
        XCTAssertTrue(json.contains("fabric-0.14.21"))
    }

    func testBuild_neoforge_includesModLoader() throws {
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(modLoader: "neoforge", modVersion: "21.0.0"),
            modPackName: "NeoForge Pack",
            modPackVersion: "1.0",
            files: []
        )
        XCTAssertTrue(json.contains("neoforge-21.0.0"))
    }

    func testBuild_quilt_includesModLoader() throws {
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(modLoader: "quilt", modVersion: "0.22.0"),
            modPackName: "Quilt Pack",
            modPackVersion: "1.0",
            files: []
        )
        XCTAssertTrue(json.contains("quilt-0.22.0"))
    }

    func testBuild_forge_noVersion_usesLoaderType() throws {
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(modLoader: "forge", modVersion: ""),
            modPackName: "Pack",
            modPackVersion: "1.0",
            files: []
        )
        XCTAssertTrue(json.contains("forge"))
    }

    // MARK: - build manifest structure

    func testBuild_manifestNameAndVersion() throws {
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "My Modpack",
            modPackVersion: "2.5.0",
            files: []
        )
        XCTAssertTrue(json.contains("My Modpack"))
        XCTAssertTrue(json.contains("2.5.0"))
    }

    func testBuild_manifestWithFiles() throws {
        let file = CurseForgeManifestBuilder.ManifestFile(
            projectID: 123,
            fileID: 456,
            required: true,
            isLocked: false
        )
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            files: [file]
        )
        XCTAssertTrue(json.contains("123"))
        XCTAssertTrue(json.contains("456"))
    }
}
