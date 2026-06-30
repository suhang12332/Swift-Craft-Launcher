//
//  ModrinthIndexFileExtendedTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ModrinthIndexFileExtendedTests: XCTestCase {
    func testModrinthIndexFile_withCurseForgeIds() {
        let file = ModrinthIndexFile(
            path: "mods/test.jar",
            hashes: ModrinthIndexFileHashes(from: [:]),
            downloads: [],
            fileSize: 1024,
            source: .curseforge,
            curseForgeProjectId: 100,
            curseForgeFileId: 200,
        )
        XCTAssertEqual(file.curseForgeProjectId, 100)
        XCTAssertEqual(file.curseForgeFileId, 200)
        XCTAssertEqual(file.source, .curseforge)
    }

    func testModrinthIndexFile_nilCurseForgeIds() {
        let file = ModrinthIndexFile(
            path: "mods/test.jar",
            hashes: ModrinthIndexFileHashes(from: [:]),
            downloads: [],
            fileSize: 1024,
        )
        XCTAssertNil(file.curseForgeProjectId)
        XCTAssertNil(file.curseForgeFileId)
        XCTAssertNil(file.source)
    }

    func testModrinthIndexFile_codable_roundTrip() throws {
        let original = ModrinthIndexFile(
            path: "mods/fabric-api.jar",
            hashes: ModrinthIndexFileHashes(from: ["sha1": "abc123"]),
            downloads: ["https://example.com/fabric-api.jar"],
            fileSize: 2048,
            env: ModrinthIndexFileEnv(client: "required", server: "unsupported"),
            source: .modrinth,
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModrinthIndexFile.self, from: data)

        XCTAssertEqual(decoded.path, "mods/fabric-api.jar")
        XCTAssertEqual(decoded.hashes.sha1, "abc123")
        XCTAssertEqual(decoded.downloads, ["https://example.com/fabric-api.jar"])
        XCTAssertEqual(decoded.fileSize, 2048)
        XCTAssertEqual(decoded.env?.client, "required")
        XCTAssertEqual(decoded.env?.server, "unsupported")
        XCTAssertEqual(decoded.source, .modrinth)
    }

    func testModrinthIndexFile_codable_withCurseForgeIds() throws {
        let original = ModrinthIndexFile(
            path: "mods/curseforge_100_200.jar",
            hashes: ModrinthIndexFileHashes(from: [:]),
            downloads: [],
            fileSize: 0,
            source: .curseforge,
            curseForgeProjectId: 100,
            curseForgeFileId: 200,
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModrinthIndexFile.self, from: data)

        XCTAssertEqual(decoded.curseForgeProjectId, 100)
        XCTAssertEqual(decoded.curseForgeFileId, 200)
        XCTAssertEqual(decoded.source, .curseforge)
    }

    func testModrinthIndexFile_codable_optionalEnv() throws {
        let json = """
        {
            "path": "mods/test.jar",
            "hashes": {"sha1": "abc"},
            "downloads": [],
            "fileSize": 0
        }
        """
        let file = try JSONDecoder().decode(ModrinthIndexFile.self, from: Data(json.utf8))
        XCTAssertNil(file.env)
        XCTAssertNil(file.source)
        XCTAssertNil(file.curseForgeProjectId)
    }

    func testModrinthIndexFileHashes_fromEmptyDict() {
        let hashes = ModrinthIndexFileHashes(from: [:])
        XCTAssertNil(hashes.sha1)
        XCTAssertNil(hashes.sha512)
        XCTAssertNil(hashes.other)
    }

    func testModrinthIndexFileHashes_fromSha1Only() {
        let hashes = ModrinthIndexFileHashes(from: ["sha1": "abc123"])
        XCTAssertEqual(hashes.sha1, "abc123")
        XCTAssertNil(hashes.sha512)
        XCTAssertNil(hashes.other)
    }

    func testModrinthIndexFileHashes_fromSha512Only() {
        let hashes = ModrinthIndexFileHashes(from: ["sha512": "def456"])
        XCTAssertNil(hashes.sha1)
        XCTAssertEqual(hashes.sha512, "def456")
        XCTAssertNil(hashes.other)
    }

    func testModrinthIndexFileHashes_fromBothStandardHashes() {
        let hashes = ModrinthIndexFileHashes(from: ["sha1": "abc", "sha512": "def"])
        XCTAssertEqual(hashes.sha1, "abc")
        XCTAssertEqual(hashes.sha512, "def")
        XCTAssertNil(hashes.other)
    }

    func testModrinthIndexFileHashes_customHashInOther() {
        let hashes = ModrinthIndexFileHashes(from: ["sha1": "abc", "murmur2": "xyz"])
        XCTAssertEqual(hashes.sha1, "abc")
        XCTAssertNil(hashes.sha512)
        XCTAssertEqual(hashes.other?["murmur2"], "xyz")
    }

    func testModrinthIndexFileHashes_multipleCustomHashes() {
        let hashes = ModrinthIndexFileHashes(from: ["sha1": "abc", "murmur2": "xyz", "md5": "123"])
        XCTAssertEqual(hashes.sha1, "abc")
        XCTAssertEqual(hashes.other?.count, 2)
        XCTAssertEqual(hashes.other?["murmur2"], "xyz")
        XCTAssertEqual(hashes.other?["md5"], "123")
    }

    func testModrinthIndexFileHashes_subscript() {
        let hashes = ModrinthIndexFileHashes(from: ["sha1": "abc", "murmur2": "xyz"])
        XCTAssertEqual(hashes["sha1"], "abc")
        XCTAssertNil(hashes["sha512"])
        XCTAssertEqual(hashes["murmur2"], "xyz")
        XCTAssertNil(hashes["unknown"])
    }

    func testModrinthIndexFileHashes_codable_roundTrip() throws {
        let original = ModrinthIndexFileHashes(from: ["sha1": "abc", "sha512": "def", "murmur2": "xyz"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModrinthIndexFileHashes.self, from: data)

        XCTAssertEqual(decoded.sha1, "abc")
        XCTAssertEqual(decoded.sha512, "def")
        XCTAssertEqual(decoded.other?["murmur2"], "xyz")
    }

    func testModrinthIndexFileHashes_codable_jsonDecode() throws {
        let json = """
        {"sha1": "abc", "sha512": "def"}
        """
        let hashes = try JSONDecoder().decode(ModrinthIndexFileHashes.self, from: Data(json.utf8))
        XCTAssertEqual(hashes.sha1, "abc")
        XCTAssertEqual(hashes.sha512, "def")
    }

    func testModrinthIndexFileHashes_codable_jsonEncode() throws {
        let hashes = ModrinthIndexFileHashes(from: ["sha1": "abc", "sha512": "def"])
        let data = try JSONEncoder().encode(hashes)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return XCTFail("Failed to parse")
        }
        XCTAssertEqual(dict["sha1"], "abc")
        XCTAssertEqual(dict["sha512"], "def")
    }

    func testFileSource_rawValues() {
        XCTAssertEqual(FileSource.modrinth.rawValue, "modrinth")
        XCTAssertEqual(FileSource.curseforge.rawValue, "curseforge")
    }

    func testFileSource_codable() throws {
        for source in [FileSource.modrinth, FileSource.curseforge] {
            let data = try JSONEncoder().encode(source)
            let decoded = try JSONDecoder().decode(FileSource.self, from: data)
            XCTAssertEqual(decoded, source)
        }
    }

    func testModrinthIndexFileEnv_codable() throws {
        let env = ModrinthIndexFileEnv(client: "required", server: "unsupported")
        let data = try JSONEncoder().encode(env)
        let decoded = try JSONDecoder().decode(ModrinthIndexFileEnv.self, from: data)
        XCTAssertEqual(decoded.client, "required")
        XCTAssertEqual(decoded.server, "unsupported")
    }

    func testModrinthIndexFileEnv_optionalFields() throws {
        let json = """
        {"client": "optional"}
        """
        let env = try JSONDecoder().decode(ModrinthIndexFileEnv.self, from: Data(json.utf8))
        XCTAssertEqual(env.client, "optional")
        XCTAssertNil(env.server)
    }

    func testModrinthIndexDependencies_codable_withLoaders() throws {
        let deps = ModrinthIndexDependencies(
            minecraft: "1.20.1",
            forgeLoader: "47.2.0",
            fabricLoader: "0.14.21",
            quiltLoader: "0.26.0",
            neoforgeLoader: "21.0.0",
            forge: nil,
            fabric: nil,
            quilt: nil,
            neoforge: nil,
            dependencies: nil,
        )
        let data = try JSONEncoder().encode(deps)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return XCTFail("Failed to parse")
        }
        XCTAssertEqual(dict["minecraft"] as? String, "1.20.1")
        XCTAssertEqual(dict["forge-loader"] as? String, "47.2.0")
        XCTAssertEqual(dict["fabric-loader"] as? String, "0.14.21")
        XCTAssertEqual(dict["quilt-loader"] as? String, "0.26.0")
        XCTAssertEqual(dict["neoforge-loader"] as? String, "21.0.0")
    }

    func testModrinthIndexDependencies_codable_withNonLoaderFields() throws {
        let deps = ModrinthIndexDependencies(
            minecraft: "1.20.1",
            forgeLoader: nil,
            fabricLoader: nil,
            quiltLoader: nil,
            neoforgeLoader: nil,
            forge: "47.2.0",
            fabric: "0.14.21",
            quilt: "0.26.0",
            neoforge: "21.0.0",
            dependencies: nil,
        )
        let data = try JSONEncoder().encode(deps)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return XCTFail("Failed to parse")
        }
        XCTAssertEqual(dict["forge"] as? String, "47.2.0")
        XCTAssertEqual(dict["fabric"] as? String, "0.14.21")
        XCTAssertEqual(dict["quilt"] as? String, "0.26.0")
        XCTAssertEqual(dict["neoforge"] as? String, "21.0.0")
    }

    func testModrinthIndexDependencies_codable_allNil() throws {
        let deps = ModrinthIndexDependencies(
            minecraft: nil,
            forgeLoader: nil,
            fabricLoader: nil,
            quiltLoader: nil,
            neoforgeLoader: nil,
            forge: nil,
            fabric: nil,
            quilt: nil,
            neoforge: nil,
            dependencies: nil,
        )
        let data = try JSONEncoder().encode(deps)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return XCTFail("Failed to parse")
        }
        XCTAssertNil(dict["minecraft"])
        XCTAssertNil(dict["forge-loader"])
    }

    func testModrinthIndexDependencies_codable_withProjectDependencies() throws {
        let deps = ModrinthIndexDependencies(
            minecraft: "1.20.1",
            forgeLoader: nil,
            fabricLoader: nil,
            quiltLoader: nil,
            neoforgeLoader: nil,
            forge: nil,
            fabric: nil,
            quilt: nil,
            neoforge: nil,
            dependencies: [
                ModrinthIndexProjectDependency(projectId: "abc", versionId: "123", dependencyType: "required"),
            ],
        )
        let data = try JSONEncoder().encode(deps)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let depsArray = dict["dependencies"] as? [[String: Any]] else {
            return XCTFail("Failed to parse")
        }
        XCTAssertEqual(depsArray.count, 1)
        XCTAssertEqual(depsArray[0]["project_id"] as? String, "abc")
        XCTAssertEqual(depsArray[0]["dependency_type"] as? String, "required")
    }

    func testModrinthIndexProjectDependency_codable() throws {
        let dep = ModrinthIndexProjectDependency(
            projectId: "abc",
            versionId: "123",
            dependencyType: "required",
        )
        let data = try JSONEncoder().encode(dep)
        let decoded = try JSONDecoder().decode(ModrinthIndexProjectDependency.self, from: data)
        XCTAssertEqual(decoded.projectId, "abc")
        XCTAssertEqual(decoded.versionId, "123")
        XCTAssertEqual(decoded.dependencyType, "required")
    }

    func testModrinthIndexProjectDependency_nilOptionalFields() throws {
        let json = """
        {"dependency_type": "optional"}
        """
        let dep = try JSONDecoder().decode(ModrinthIndexProjectDependency.self, from: Data(json.utf8))
        XCTAssertNil(dep.projectId)
        XCTAssertNil(dep.versionId)
        XCTAssertEqual(dep.dependencyType, "optional")
    }

    func testModrinthIndexInfo_init() {
        let info = ModrinthIndexInfo(
            gameVersion: "1.20.1",
            loaderType: "fabric",
            loaderVersion: "0.14.21",
            modPackName: "TestPack",
            modPackVersion: "1.0",
            summary: "A test pack",
            files: [],
            dependencies: [],
            source: .modrinth,
        )
        XCTAssertEqual(info.gameVersion, "1.20.1")
        XCTAssertEqual(info.loaderType, "fabric")
        XCTAssertEqual(info.loaderVersion, "0.14.21")
        XCTAssertEqual(info.modPackName, "TestPack")
        XCTAssertEqual(info.modPackVersion, "1.0")
        XCTAssertEqual(info.summary, "A test pack")
        XCTAssertTrue(info.files.isEmpty)
        XCTAssertTrue(info.dependencies.isEmpty)
        XCTAssertEqual(info.source, .modrinth)
    }

    func testModrinthIndexInfo_defaultSource() {
        let info = ModrinthIndexInfo(
            gameVersion: "1.20.1",
            loaderType: "vanilla",
            loaderVersion: "",
            modPackName: "Test",
            modPackVersion: "1.0",
            summary: nil,
            files: [],
            dependencies: [],
        )
        XCTAssertEqual(info.source, .modrinth)
    }

    func testModrinthIndexInfo_curseforgeSource() {
        let info = ModrinthIndexInfo(
            gameVersion: "1.20.1",
            loaderType: "forge",
            loaderVersion: "47.2.0",
            modPackName: "CFPack",
            modPackVersion: "1.0",
            summary: nil,
            files: [],
            dependencies: [],
            source: .curseforge,
        )
        XCTAssertEqual(info.source, .curseforge)
    }
}
