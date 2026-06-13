import XCTest
@testable import SwiftCraftLauncher

final class CurseForgeManifestBuilderExtendedTests: XCTestCase {

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

    private func parseJSON(_ json: String) throws -> [String: Any] {
        let data = Data(json.utf8)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "test", code: 1)
        }
        return dict
    }

    // MARK: - Vanilla loader

    func testBuild_vanilla_noModLoaders() throws {
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(modLoader: "vanilla", modVersion: ""),
            modPackName: "VanillaPack",
            modPackVersion: "1.0",
            files: []
        )
        let dict = try parseJSON(json)
        guard let minecraft = dict["minecraft"] as? [String: Any],
              let modLoaders = minecraft["modLoaders"] as? [Any] else {
            return XCTFail("Failed to parse minecraft.modLoaders")
        }
        XCTAssertTrue(modLoaders.isEmpty)
    }

    func testBuild_vanilla_emptyModLoadersArray() throws {
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(modLoader: "vanilla", modVersion: ""),
            modPackName: "VanillaPack",
            modPackVersion: "1.0",
            files: []
        )

        let dict = try parseJSON(json)
        guard let minecraft = dict["minecraft"] as? [String: Any],
              let modLoaders = minecraft["modLoaders"] as? [Any] else {
            return XCTFail("Failed to parse minecraft.modLoaders")
        }
        XCTAssertTrue(modLoaders.isEmpty)
    }

    // MARK: - JSON structure

    func testBuild_containsManifestType() throws {
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            files: []
        )
        XCTAssertTrue(json.contains("minecraftModpack"))
    }

    func testBuild_containsManifestVersion() throws {
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            files: []
        )

        let dict = try parseJSON(json)
        XCTAssertEqual(dict["manifestVersion"] as? Int, 1)
    }

    func testBuild_containsOverrides() throws {
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            files: []
        )
        XCTAssertTrue(json.contains("overrides"))
    }

    func testBuild_containsNameAndVersion() throws {
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "MyPack",
            modPackVersion: "2.0",
            files: []
        )
        XCTAssertTrue(json.contains("MyPack"))
        XCTAssertTrue(json.contains("2.0"))
    }

    func testBuild_containsMinecraftVersion() throws {
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(gameVersion: "1.21.1"),
            modPackName: "Test",
            modPackVersion: "1.0",
            files: []
        )
        XCTAssertTrue(json.contains("1.21.1"))
    }

    // MARK: - Mod loader ID format

    func testBuild_forgeLoaderIdFormat() throws {
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(modLoader: "forge", modVersion: "47.2.0"),
            modPackName: "Test",
            modPackVersion: "1.0",
            files: []
        )
        XCTAssertTrue(json.contains("forge-47.2.0"))
    }

    func testBuild_fabricLoaderIdFormat() throws {
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(modLoader: "fabric", modVersion: "0.14.21"),
            modPackName: "Test",
            modPackVersion: "1.0",
            files: []
        )
        XCTAssertTrue(json.contains("fabric-0.14.21"))
    }

    func testBuild_neoforgeLoaderIdFormat() throws {
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(modLoader: "neoforge", modVersion: "21.0.0"),
            modPackName: "Test",
            modPackVersion: "1.0",
            files: []
        )
        XCTAssertTrue(json.contains("neoforge-21.0.0"))
    }

    func testBuild_quiltLoaderIdFormat() throws {
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(modLoader: "quilt", modVersion: "0.26.0"),
            modPackName: "Test",
            modPackVersion: "1.0",
            files: []
        )
        XCTAssertTrue(json.contains("quilt-0.26.0"))
    }

    func testBuild_emptyLoaderVersion_noDashSuffix() throws {
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(modLoader: "forge", modVersion: ""),
            modPackName: "Test",
            modPackVersion: "1.0",
            files: []
        )

        let dict = try parseJSON(json)
        guard let minecraft = dict["minecraft"] as? [String: Any],
              let modLoaders = minecraft["modLoaders"] as? [[String: Any]] else {
            return XCTFail("Failed to parse modLoaders")
        }
        XCTAssertEqual(modLoaders.first?["id"] as? String, "forge")
    }

    // MARK: - ManifestFile

    func testBuild_filesEncoded() throws {
        let files = [
            CurseForgeManifestBuilder.ManifestFile(projectID: 100, fileID: 200, required: true, isLocked: false),
        ]

        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            files: files
        )

        let dict = try parseJSON(json)
        guard let filesArray = dict["files"] as? [[String: Any]] else {
            return XCTFail("Failed to parse files")
        }
        XCTAssertEqual(filesArray.count, 1)
        XCTAssertEqual(filesArray[0]["projectID"] as? Int, 100)
        XCTAssertEqual(filesArray[0]["fileID"] as? Int, 200)
        XCTAssertEqual(filesArray[0]["required"] as? Bool, true)
    }

    func testBuild_multipleFiles() throws {
        let files = [
            CurseForgeManifestBuilder.ManifestFile(projectID: 1, fileID: 10, required: true, isLocked: false),
            CurseForgeManifestBuilder.ManifestFile(projectID: 2, fileID: 20, required: false, isLocked: true),
            CurseForgeManifestBuilder.ManifestFile(projectID: 3, fileID: 30, required: true, isLocked: false),
        ]

        let json = try CurseForgeManifestBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            files: files
        )

        let dict = try parseJSON(json)
        guard let filesArray = dict["files"] as? [[String: Any]] else {
            return XCTFail("Failed to parse files")
        }
        XCTAssertEqual(filesArray.count, 3)
    }
}
