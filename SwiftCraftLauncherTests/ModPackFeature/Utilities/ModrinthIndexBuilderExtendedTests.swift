import XCTest
@testable import SwiftCraftLauncher

final class ModrinthIndexBuilderExtendedTests: XCTestCase {

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

    private func parseJSON(_ json: String) throws -> [String: Any] {
        guard let dict = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else {
            throw NSError(domain: "test", code: 1)
        }
        return dict
    }

    // MARK: - JSON structure

    func testBuild_jsonContainsFormatVersion() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: []
        )
        let dict = try parseJSON(json)
        XCTAssertEqual(dict["formatVersion"] as? Int, 1)
    }

    func testBuild_jsonContainsGame() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: []
        )
        let dict = try parseJSON(json)
        XCTAssertEqual(dict["game"] as? String, "minecraft")
    }

    func testBuild_jsonContainsNameAndVersion() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "MyPack",
            modPackVersion: "2.0",
            summary: nil,
            files: []
        )
        let dict = try parseJSON(json)
        XCTAssertEqual(dict["name"] as? String, "MyPack")
        XCTAssertEqual(dict["versionId"] as? String, "2.0")
    }

    func testBuild_withSummary() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: "A great pack",
            files: []
        )
        let dict = try parseJSON(json)
        XCTAssertEqual(dict["summary"] as? String, "A great pack")
    }

    func testBuild_nilSummary_excluded() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: []
        )
        let dict = try parseJSON(json)
        XCTAssertNil(dict["summary"])
    }

    // MARK: - Files encoding

    func testBuild_emptyFiles() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: []
        )
        let dict = try parseJSON(json)
        guard let files = dict["files"] as? [[String: Any]] else { return XCTFail("Failed to parse files") }
        XCTAssertTrue(files.isEmpty)
    }

    func testBuild_singleFile() async throws {
        let file = makeFile(path: "mods/fabric-api.jar", sha1: "abc123")
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: [file]
        )
        let dict = try parseJSON(json)
        guard let files = dict["files"] as? [[String: Any]] else { return XCTFail("Failed to parse files") }
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0]["path"] as? String, "mods/fabric-api.jar")
        XCTAssertEqual(files[0]["fileSize"] as? Int, 1024)
    }

    func testBuild_fileWithEnv() async throws {
        let file = ModrinthIndexFile(
            path: "mods/test.jar",
            hashes: ModrinthIndexFileHashes(from: [:]),
            downloads: [],
            fileSize: 0,
            env: ModrinthIndexFileEnv(client: "required", server: "unsupported")
        )
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: [file]
        )
        let dict = try parseJSON(json)
        guard let files = dict["files"] as? [[String: Any]],
              let env = files[0]["env"] as? [String: String] else {
            return XCTFail("Failed to parse env")
        }
        XCTAssertEqual(env["client"], "required")
        XCTAssertEqual(env["server"], "unsupported")
    }

    func testBuild_fileWithoutEnv_noEnvKey() async throws {
        let file = makeFile()
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: [file]
        )
        let dict = try parseJSON(json)
        guard let files = dict["files"] as? [[String: Any]] else { return XCTFail("Failed to parse files") }
        XCTAssertNil(files[0]["env"])
    }

    // MARK: - Dependencies structure

    func testBuild_dependenciesContainsMinecraft() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(gameVersion: "1.21.1"),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: []
        )
        let dict = try parseJSON(json)
        guard let deps = dict["dependencies"] as? [String: Any] else { return XCTFail("Failed to parse deps") }
        XCTAssertEqual(deps["minecraft"] as? String, "1.21.1")
    }

    func testBuild_fabricDependencyKey() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(modLoader: "fabric", modVersion: "0.14.21"),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: []
        )
        let dict = try parseJSON(json)
        guard let deps = dict["dependencies"] as? [String: Any] else { return XCTFail("Failed to parse deps") }
        XCTAssertEqual(deps["fabric-loader"] as? String, "0.14.21")
        XCTAssertNil(deps["forge-loader"])
    }

    func testBuild_forgeDependencyKey() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(modLoader: "forge", modVersion: "47.2.0"),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: []
        )
        let dict = try parseJSON(json)
        guard let deps = dict["dependencies"] as? [String: Any] else { return XCTFail("Failed to parse deps") }
        XCTAssertEqual(deps["forge-loader"] as? String, "47.2.0")
    }

    func testBuild_neoforgeDependencyKey() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(modLoader: "neoforge", modVersion: "21.0.0"),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: []
        )
        let dict = try parseJSON(json)
        guard let deps = dict["dependencies"] as? [String: Any] else { return XCTFail("Failed to parse deps") }
        XCTAssertEqual(deps["neoforge-loader"] as? String, "21.0.0")
    }

    func testBuild_quiltDependencyKey() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(modLoader: "quilt", modVersion: "0.26.0"),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: []
        )
        let dict = try parseJSON(json)
        guard let deps = dict["dependencies"] as? [String: Any] else { return XCTFail("Failed to parse deps") }
        XCTAssertEqual(deps["quilt-loader"] as? String, "0.26.0")
    }

    func testBuild_vanilla_noLoaderDependency() async throws {
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(modLoader: "vanilla", modVersion: ""),
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: []
        )
        let dict = try parseJSON(json)
        guard let deps = dict["dependencies"] as? [String: Any] else { return XCTFail("Failed to parse deps") }
        XCTAssertNil(deps["forge-loader"])
        XCTAssertNil(deps["fabric-loader"])
        XCTAssertNil(deps["quilt-loader"])
        XCTAssertNil(deps["neoforge-loader"])
    }

    // MARK: - Full round-trip decode

    func testBuild_outputDecodableAsModrinthIndex() async throws {
        let file = makeFile()
        let json = try await ModrinthIndexBuilder.build(
            gameInfo: makeGameInfo(),
            modPackName: "TestPack",
            modPackVersion: "1.0",
            summary: "Test summary",
            files: [file]
        )
        let index = try JSONDecoder().decode(ModrinthIndex.self, from: Data(json.utf8))

        XCTAssertEqual(index.formatVersion, 1)
        XCTAssertEqual(index.game, "minecraft")
        XCTAssertEqual(index.versionId, "1.0")
        XCTAssertEqual(index.name, "TestPack")
        XCTAssertEqual(index.summary, "Test summary")
        XCTAssertEqual(index.files.count, 1)
        XCTAssertEqual(index.dependencies.minecraft, "1.20.1")
    }
}
