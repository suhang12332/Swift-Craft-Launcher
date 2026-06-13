import XCTest
@testable import SwiftCraftLauncher

final class CurseForgeManifestParserTests: XCTestCase {
    func testParseManifest_forgeLoader() async throws {
        let directory = try await copyFixtureDirectory(named: "forge_manifest")

        let result = await CurseForgeManifestParser.parseManifest(extractedPath: directory)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.modPackName, "Test Pack")
        XCTAssertEqual(result?.modPackVersion, "1.0.0")
        XCTAssertEqual(result?.gameVersion, "1.20.1")
        XCTAssertEqual(result?.loaderType, GameLoader.forge.displayName)
        XCTAssertEqual(result?.loaderVersion, "47.2.0")
        XCTAssertEqual(result?.files.count, 1)
        XCTAssertEqual(result?.source, .curseforge)
    }

    func testParseManifest_fabricLoader() async throws {
        let directory = try await copyFixtureDirectory(named: "fabric_manifest")

        let result = await CurseForgeManifestParser.parseManifest(extractedPath: directory)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.loaderType, GameLoader.fabric.displayName)
        XCTAssertEqual(result?.loaderVersion, "0.14.21")
    }

    func testParseManifest_missingManifest_returnsNil() async throws {
        let directory = try TestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = await CurseForgeManifestParser.parseManifest(extractedPath: directory)
        XCTAssertNil(result)
    }

    func testParseManifest_autoGeneratesVersion() async throws {
        let directory = try await copyFixtureDirectory(named: "no_version_manifest")

        let result = await CurseForgeManifestParser.parseManifest(extractedPath: directory)

        XCTAssertNotNil(result)
        XCTAssertFalse(result?.modPackVersion.isEmpty ?? true)
        XCTAssertTrue(result?.modPackVersion.contains("1.20.1") ?? false)
        XCTAssertTrue(result?.modPackVersion.contains(GameLoader.forge.displayName) ?? false)
    }

    func testParseManifest_emptyFiles() async throws {
        let directory = try await copyFixtureDirectory(named: "empty_files_manifest")

        let result = await CurseForgeManifestParser.parseManifest(extractedPath: directory)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.files.count, 0)
    }

    func testParseManifest_invalidJSON_returnsNil() async throws {
        let directory = try TestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let manifestURL = directory.appendingPathComponent("manifest.json")
        try Data("{".utf8).write(to: manifestURL)

        let result = await CurseForgeManifestParser.parseManifest(extractedPath: directory)
        XCTAssertNil(result)
    }

    private func copyFixtureDirectory(named name: String) async throws -> URL {
        let directory = try TestSupport.makeTemporaryDirectory()
        let fixtureURL = TestSupport.fixtureURL(
            subdirectory: "Fixtures/curseforge",
            name: name,
            extension: "json"
        )
        let destination = directory.appendingPathComponent("manifest.json")
        try FileManager.default.copyItem(at: fixtureURL, to: destination)
        return directory
    }
}
