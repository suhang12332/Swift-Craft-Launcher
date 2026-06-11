import XCTest
@testable import SwiftCraftLauncher

final class ModrinthIndexDependenciesExtendedTests: XCTestCase {

    // MARK: - All nil case

    func testAllNil() throws {
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
            dependencies: nil
        )

        let data = try JSONEncoder().encode(deps)
        let decoded = try JSONDecoder().decode(ModrinthIndexDependencies.self, from: data)

        XCTAssertNil(decoded.minecraft)
        XCTAssertNil(decoded.forgeLoader)
        XCTAssertNil(decoded.fabricLoader)
        XCTAssertNil(decoded.quiltLoader)
        XCTAssertNil(decoded.neoforgeLoader)
        XCTAssertNil(decoded.forge)
        XCTAssertNil(decoded.fabric)
        XCTAssertNil(decoded.quilt)
        XCTAssertNil(decoded.neoforge)
        XCTAssertNil(decoded.dependencies)
    }

    // MARK: - CodingKeys for quilt-loader and neoforge-loader

    func testCodingKeys_quiltLoader() throws {
        let json = """
        {"minecraft": "1.20.1", "quilt-loader": "0.22.0"}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ModrinthIndexDependencies.self, from: data)

        XCTAssertEqual(decoded.minecraft, "1.20.1")
        XCTAssertEqual(decoded.quiltLoader, "0.22.0")
        XCTAssertNil(decoded.fabricLoader)
        XCTAssertNil(decoded.forgeLoader)
    }

    func testCodingKeys_neoforgeLoader() throws {
        let json = """
        {"minecraft": "1.20.4", "neoforge-loader": "21.0.0"}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ModrinthIndexDependencies.self, from: data)

        XCTAssertEqual(decoded.minecraft, "1.20.4")
        XCTAssertEqual(decoded.neoforgeLoader, "21.0.0")
    }

    func testCodingKeys_allLoaders() throws {
        let json = """
        {
            "minecraft": "1.20.1",
            "forge-loader": "47.2.0",
            "fabric-loader": "0.14.21",
            "quilt-loader": "0.22.0",
            "neoforge-loader": "21.0.0"
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ModrinthIndexDependencies.self, from: data)

        XCTAssertEqual(decoded.forgeLoader, "47.2.0")
        XCTAssertEqual(decoded.fabricLoader, "0.14.21")
        XCTAssertEqual(decoded.quiltLoader, "0.22.0")
        XCTAssertEqual(decoded.neoforgeLoader, "21.0.0")
    }

    func testCodingKeys_withDependencies() throws {
        let json = """
        {
            "minecraft": "1.20.1",
            "dependencies": [
                {"project_id": "proj1", "version_id": "ver1", "dependency_type": "required"},
                {"project_id": "proj2", "version_id": null, "dependency_type": "optional"}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ModrinthIndexDependencies.self, from: data)

        XCTAssertEqual(decoded.dependencies?.count, 2)
        XCTAssertEqual(decoded.dependencies?[0].projectId, "proj1")
        XCTAssertEqual(decoded.dependencies?[0].dependencyType, "required")
        XCTAssertNil(decoded.dependencies?[1].versionId)
    }

    // MARK: - ModrinthIndexProjectDependency edge cases

    func testDependency_nilProjectId() throws {
        let json = """
        {"project_id": null, "version_id": "ver1", "dependency_type": "required"}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ModrinthIndexProjectDependency.self, from: data)

        XCTAssertNil(decoded.projectId)
        XCTAssertEqual(decoded.versionId, "ver1")
    }

    func testDependency_nilVersionId() throws {
        let dep = ModrinthIndexProjectDependency(
            projectId: "p1",
            versionId: nil,
            dependencyType: "incompatible"
        )

        let data = try JSONEncoder().encode(dep)
        let decoded = try JSONDecoder().decode(ModrinthIndexProjectDependency.self, from: data)

        XCTAssertEqual(decoded.projectId, "p1")
        XCTAssertNil(decoded.versionId)
        XCTAssertEqual(decoded.dependencyType, "incompatible")
    }

    // MARK: - ModrinthIndexFileHashes empty dict

    func testHashes_emptyDict() {
        let hashes = ModrinthIndexFileHashes(from: [:])

        XCTAssertNil(hashes.sha1)
        XCTAssertNil(hashes.sha512)
        XCTAssertNil(hashes.other)
    }

    func testHashes_onlySha512() {
        let hashes = ModrinthIndexFileHashes(from: ["sha512": "abc"])

        XCTAssertNil(hashes.sha1)
        XCTAssertEqual(hashes.sha512, "abc")
        XCTAssertNil(hashes.other)
    }

    func testHashes_multipleOtherHashes() {
        let hashes = ModrinthIndexFileHashes(from: ["md5": "a", "sha256": "b", "xxhash": "c"])

        XCTAssertNil(hashes.sha1)
        XCTAssertNil(hashes.sha512)
        XCTAssertEqual(hashes.other?.count, 3)
        XCTAssertEqual(hashes.other?["md5"], "a")
        XCTAssertEqual(hashes.other?["sha256"], "b")
        XCTAssertEqual(hashes.other?["xxhash"], "c")
    }

    func testHashes_subscript_allKeys() {
        let hashes = ModrinthIndexFileHashes(from: [
            "sha1": "s1", "sha512": "s512", "md5": "m"
        ])

        XCTAssertEqual(hashes["sha1"], "s1")
        XCTAssertEqual(hashes["sha512"], "s512")
        XCTAssertEqual(hashes["md5"], "m")
        XCTAssertNil(hashes["nonexistent"])
    }

    func testHashes_codable_empty() throws {
        let hashes = ModrinthIndexFileHashes(from: [:])
        let data = try JSONEncoder().encode(hashes)
        let decoded = try JSONDecoder().decode(ModrinthIndexFileHashes.self, from: data)

        XCTAssertNil(decoded.sha1)
        XCTAssertNil(decoded.sha512)
    }

    // MARK: - ModrinthIndexFile edge cases

    func testModrinthIndexFile_nilEnvAndSource() throws {
        let file = ModrinthIndexFile(
            path: "mods/test.jar",
            hashes: ModrinthIndexFileHashes(from: ["sha1": "abc"]),
            downloads: ["https://example.com/test.jar"],
            fileSize: 1024,
            env: nil,
            source: nil,
            curseForgeProjectId: nil,
            curseForgeFileId: nil
        )

        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(ModrinthIndexFile.self, from: data)

        XCTAssertNil(decoded.env)
        XCTAssertNil(decoded.source)
        XCTAssertNil(decoded.curseForgeProjectId)
        XCTAssertNil(decoded.curseForgeFileId)
    }

    func testModrinthIndexFile_multipleDownloads() {
        let file = ModrinthIndexFile(
            path: "mods/test.jar",
            hashes: ModrinthIndexFileHashes(from: ["sha1": "abc"]),
            downloads: [
                "https://modrinth.com/test.jar",
                "https://cdn.example.com/test.jar",
            ],
            fileSize: 2048
        )

        XCTAssertEqual(file.downloads.count, 2)
        XCTAssertEqual(file.fileSize, 2048)
    }

    func testModrinthIndexFile_curseForgeFields() {
        let file = ModrinthIndexFile(
            path: "mods/test.jar",
            hashes: ModrinthIndexFileHashes(from: ["sha1": "abc"]),
            downloads: [],
            fileSize: 1024,
            env: ModrinthIndexFileEnv(client: "required", server: "unsupported"),
            source: .curseforge,
            curseForgeProjectId: 12345,
            curseForgeFileId: 67890
        )

        XCTAssertEqual(file.source, .curseforge)
        XCTAssertEqual(file.curseForgeProjectId, 12345)
        XCTAssertEqual(file.curseForgeFileId, 67890)
        XCTAssertEqual(file.env?.client, "required")
        XCTAssertEqual(file.env?.server, "unsupported")
    }

    // MARK: - ModrinthIndexFileEnv

    func testFileEnv_clientOnly() throws {
        let env = ModrinthIndexFileEnv(client: "required", server: nil)
        let data = try JSONEncoder().encode(env)
        let decoded = try JSONDecoder().decode(ModrinthIndexFileEnv.self, from: data)

        XCTAssertEqual(decoded.client, "required")
        XCTAssertNil(decoded.server)
    }

    func testFileEnv_serverOnly() throws {
        let env = ModrinthIndexFileEnv(client: nil, server: "optional")
        let data = try JSONEncoder().encode(env)
        let decoded = try JSONDecoder().decode(ModrinthIndexFileEnv.self, from: data)

        XCTAssertNil(decoded.client)
        XCTAssertEqual(decoded.server, "optional")
    }

    // MARK: - ModrinthIndexFile codingKeys

    func testModrinthIndexFile_codingKeys_fileSize() throws {
        let json = """
        {
            "path": "mods/test.jar",
            "hashes": {"sha1": "abc"},
            "downloads": [],
            "fileSize": 1024
        }
        """
        let data = json.data(using: .utf8)!
        let file = try JSONDecoder().decode(ModrinthIndexFile.self, from: data)

        XCTAssertEqual(file.path, "mods/test.jar")
        XCTAssertEqual(file.fileSize, 1024)
    }

    func testModrinthIndexFile_codable_roundTrip() throws {
        let original = ModrinthIndexFile(
            path: "mods/test.jar",
            hashes: ModrinthIndexFileHashes(from: ["sha1": "abc"]),
            downloads: ["https://example.com/test.jar"],
            fileSize: 1024,
            env: nil,
            source: .modrinth
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModrinthIndexFile.self, from: data)

        XCTAssertEqual(decoded.path, original.path)
        XCTAssertEqual(decoded.hashes.sha1, original.hashes.sha1)
        XCTAssertEqual(decoded.fileSize, original.fileSize)
        XCTAssertEqual(decoded.source, .modrinth)
    }

    // MARK: - ModrinthIndex edge cases

    func testModrinthIndex_fromJSON() throws {
        let json = """
        {
            "formatVersion": 1,
            "game": "minecraft",
            "versionId": "1.0.0",
            "name": "Test Pack",
            "files": [],
            "dependencies": {"minecraft": "1.20.1"}
        }
        """
        let data = json.data(using: .utf8)!
        let index = try JSONDecoder().decode(ModrinthIndex.self, from: data)

        XCTAssertEqual(index.formatVersion, 1)
        XCTAssertEqual(index.game, "minecraft")
        XCTAssertNil(index.summary)
    }

    func testModrinthIndex_codingKeys() throws {
        let json = """
        {
            "formatVersion": 1,
            "game": "minecraft",
            "versionId": "1.0.0",
            "name": "Test",
            "summary": "A test pack",
            "files": [],
            "dependencies": {}
        }
        """
        let data = json.data(using: .utf8)!
        let index = try JSONDecoder().decode(ModrinthIndex.self, from: data)

        XCTAssertEqual(index.formatVersion, 1)
        XCTAssertEqual(index.versionId, "1.0.0")
        XCTAssertEqual(index.summary, "A test pack")
    }
}
