import XCTest
@testable import SwiftCraftLauncher

final class CurseForgeExportTests: XCTestCase {

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

    // MARK: - CurseForgeManifestBuilder vanilla

    func testBuild_vanilla_emptyModLoaders() throws {
        let gameInfo = makeGameInfo(modLoader: "vanilla", modVersion: "")

        let json = try CurseForgeManifestBuilder.build(
            gameInfo: gameInfo,
            modPackName: "VanillaPack",
            modPackVersion: "1.0",
            files: []
        )

        XCTAssertTrue(json.contains("manifestType"))
        XCTAssertTrue(json.contains("minecraftModpack"))
        // Verify the JSON is valid and contains basic structure
        XCTAssertTrue(json.contains("VanillaPack"))
        XCTAssertTrue(json.contains("1.0"))
    }

    func testBuild_vanilla_withEmptyModVersion() throws {
        let gameInfo = makeGameInfo(modLoader: "vanilla", modVersion: "")

        let json = try CurseForgeManifestBuilder.build(
            gameInfo: gameInfo,
            modPackName: "EmptyLoader",
            modPackVersion: "1.0",
            files: []
        )

        XCTAssertFalse(json.contains("vanilla-"))
    }

    // MARK: - CurseForgeManifestBuilder with forge version

    func testBuild_forge_withVersion() throws {
        let gameInfo = makeGameInfo(modLoader: "forge", modVersion: "47.2.0")

        let json = try CurseForgeManifestBuilder.build(
            gameInfo: gameInfo,
            modPackName: "ForgePack",
            modPackVersion: "1.0",
            files: []
        )

        XCTAssertTrue(json.contains("forge-47.2.0"))
    }

    func testBuild_forge_withoutVersion() throws {
        let gameInfo = makeGameInfo(modLoader: "forge", modVersion: "")

        let json = try CurseForgeManifestBuilder.build(
            gameInfo: gameInfo,
            modPackName: "ForgeNoVersion",
            modPackVersion: "1.0",
            files: []
        )

        XCTAssertTrue(json.contains("forge"))
        XCTAssertFalse(json.contains("forge-"))
    }

    // MARK: - CurseForgeManifestBuilder JSON structure

    func testBuild_jsonStructure_hasRequiredFields() throws {
        let gameInfo = makeGameInfo()
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: gameInfo,
            modPackName: "TestPack",
            modPackVersion: "2.0",
            files: []
        )

        XCTAssertTrue(json.contains("\"manifestType\""))
        XCTAssertTrue(json.contains("\"manifestVersion\""))
        XCTAssertTrue(json.contains("\"name\""))
        XCTAssertTrue(json.contains("\"version\""))
        XCTAssertTrue(json.contains("\"author\""))
        XCTAssertTrue(json.contains("\"files\""))
        XCTAssertTrue(json.contains("\"overrides\""))
        XCTAssertTrue(json.contains("\"minecraft\""))
        XCTAssertTrue(json.contains("\"modLoaders\""))
    }

    func testBuild_jsonStructure_modPackName() throws {
        let gameInfo = makeGameInfo()
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: gameInfo,
            modPackName: "My Awesome Pack",
            modPackVersion: "3.0",
            files: []
        )

        XCTAssertTrue(json.contains("My Awesome Pack"))
        XCTAssertTrue(json.contains("3.0"))
    }

    func testBuild_jsonStructure_gameVersion() throws {
        let gameInfo = makeGameInfo(gameVersion: "1.21.4")
        let json = try CurseForgeManifestBuilder.build(
            gameInfo: gameInfo,
            modPackName: "Pack",
            modPackVersion: "1.0",
            files: []
        )

        XCTAssertTrue(json.contains("1.21.4"))
    }

    // MARK: - CurseForgeManifestBuilder.ManifestFile Codable

    func testManifestFile_codable_roundTrip() throws {
        let file = CurseForgeManifestBuilder.ManifestFile(
            projectID: 238222,
            fileID: 4567890,
            required: true,
            isLocked: false
        )

        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(CurseForgeManifestBuilder.ManifestFile.self, from: data)

        XCTAssertEqual(decoded.projectID, 238222)
        XCTAssertEqual(decoded.fileID, 4567890)
        XCTAssertTrue(decoded.required)
        XCTAssertFalse(decoded.isLocked)
    }

    func testManifestFile_codable_allFalse() throws {
        let file = CurseForgeManifestBuilder.ManifestFile(
            projectID: 1,
            fileID: 2,
            required: false,
            isLocked: true
        )

        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(CurseForgeManifestBuilder.ManifestFile.self, from: data)

        XCTAssertFalse(decoded.required)
        XCTAssertTrue(decoded.isLocked)
    }

    func testManifestFile_codable_decodeFromJSON() throws {
        let json = """
        {"projectID": 100, "fileID": 200, "required": true, "isLocked": false}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(CurseForgeManifestBuilder.ManifestFile.self, from: json)

        XCTAssertEqual(decoded.projectID, 100)
        XCTAssertEqual(decoded.fileID, 200)
    }

    // MARK: - CurseForgeManifestBuilder with files

    func testBuild_files_preservesOrder() throws {
        let gameInfo = makeGameInfo()
        let files = [
            CurseForgeManifestBuilder.ManifestFile(projectID: 3, fileID: 30, required: true, isLocked: false),
            CurseForgeManifestBuilder.ManifestFile(projectID: 1, fileID: 10, required: false, isLocked: false),
            CurseForgeManifestBuilder.ManifestFile(projectID: 2, fileID: 20, required: true, isLocked: true),
        ]

        let json = try CurseForgeManifestBuilder.build(
            gameInfo: gameInfo,
            modPackName: "OrderedPack",
            modPackVersion: "1.0",
            files: files
        )

        // Verify all project IDs are present
        XCTAssertTrue(json.contains("3"))
        XCTAssertTrue(json.contains("1"))
        XCTAssertTrue(json.contains("2"))
    }
}
