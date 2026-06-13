import XCTest
@testable import SwiftCraftLauncher

final class ModrinthIndexExtendedTests: XCTestCase {

    // MARK: - ModrinthIndexFileHashes Codable

    func testModrinthIndexFileHashes_codable_roundTrip() throws {
        let hashes = ModrinthIndexFileHashes(from: ["sha1": "abc123", "sha512": "def456", "md5": "xyz789"])
        let data = try JSONEncoder().encode(hashes)
        let decoded = try JSONDecoder().decode(ModrinthIndexFileHashes.self, from: data)

        XCTAssertEqual(decoded.sha1, "abc123")
        XCTAssertEqual(decoded.sha512, "def456")
        XCTAssertEqual(decoded.other?["md5"], "xyz789")
    }

    func testModrinthIndexFileHashes_codable_sha1Only() throws {
        let hashes = ModrinthIndexFileHashes(from: ["sha1": "onlysha1"])
        let data = try JSONEncoder().encode(hashes)
        let decoded = try JSONDecoder().decode(ModrinthIndexFileHashes.self, from: data)

        XCTAssertEqual(decoded.sha1, "onlysha1")
        XCTAssertNil(decoded.sha512)
        XCTAssertNil(decoded.other)
    }

    func testModrinthIndexFileHashes_codable_emptyDict() throws {
        let hashes = ModrinthIndexFileHashes(from: [:])
        let data = try JSONEncoder().encode(hashes)
        let decoded = try JSONDecoder().decode(ModrinthIndexFileHashes.self, from: data)

        XCTAssertNil(decoded.sha1)
        XCTAssertNil(decoded.sha512)
        XCTAssertNil(decoded.other)
    }

    func testModrinthIndexFileHashes_codable_onlyOtherHashes() throws {
        let hashes = ModrinthIndexFileHashes(from: ["md5": "abc", "shake128": "def"])
        let data = try JSONEncoder().encode(hashes)
        let decoded = try JSONDecoder().decode(ModrinthIndexFileHashes.self, from: data)

        XCTAssertNil(decoded.sha1)
        XCTAssertNil(decoded.sha512)
        XCTAssertEqual(decoded.other?["md5"], "abc")
        XCTAssertEqual(decoded.other?["shake128"], "def")
    }

    func testModrinthIndexFileHashes_decode_fromJSON() throws {
        let json = Data("""
        {"sha1": "a1b2c3", "sha512": "d4e5f6", "custom_hash": "abc123"}
        """.utf8)
        let decoded = try JSONDecoder().decode(ModrinthIndexFileHashes.self, from: json)

        XCTAssertEqual(decoded.sha1, "a1b2c3")
        XCTAssertEqual(decoded.sha512, "d4e5f6")
        XCTAssertEqual(decoded.other?["custom_hash"], "abc123")
    }

    // MARK: - ModrinthIndexFile full Codable

    func testModrinthIndexFile_codable_withEnv() throws {
        let file = ModrinthIndexFile(
            path: "mods/fabric-api.jar",
            hashes: ModrinthIndexFileHashes(from: ["sha1": "abc"]),
            downloads: ["https://modrinth.com/mod/fabric-api"],
            fileSize: 2048,
            env: ModrinthIndexFileEnv(client: "required", server: "optional"),
            source: .modrinth
        )

        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(ModrinthIndexFile.self, from: data)

        XCTAssertEqual(decoded.path, "mods/fabric-api.jar")
        XCTAssertEqual(decoded.env?.client, "required")
        XCTAssertEqual(decoded.env?.server, "optional")
        XCTAssertEqual(decoded.source, .modrinth)
        XCTAssertNil(decoded.curseForgeProjectId)
        XCTAssertNil(decoded.curseForgeFileId)
    }

    func testModrinthIndexFile_codable_withCurseForgeIds() throws {
        let file = ModrinthIndexFile(
            path: "mods/jei.jar",
            hashes: ModrinthIndexFileHashes(from: ["sha1": "def"]),
            downloads: [],
            fileSize: 0,
            env: nil,
            source: .curseforge,
            curseForgeProjectId: 238222,
            curseForgeFileId: 4567890
        )

        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(ModrinthIndexFile.self, from: data)

        XCTAssertEqual(decoded.curseForgeProjectId, 238222)
        XCTAssertEqual(decoded.curseForgeFileId, 4567890)
        XCTAssertEqual(decoded.source, .curseforge)
    }

    func testModrinthIndexFile_codable_noEnv() throws {
        let file = ModrinthIndexFile(
            path: "config/settings.json",
            hashes: ModrinthIndexFileHashes(from: [:]),
            downloads: [],
            fileSize: 128,
            env: nil,
            source: nil
        )

        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(ModrinthIndexFile.self, from: data)

        XCTAssertNil(decoded.env)
        XCTAssertNil(decoded.source)
    }

    // MARK: - ModrinthIndex full Codable

    func testModrinthIndex_codable_withFiles() throws {
        let files = [
            ModrinthIndexFile(
                path: "mods/fabric-api.jar",
                hashes: ModrinthIndexFileHashes(from: ["sha1": "abc"]),
                downloads: ["https://example.com/fabric-api.jar"],
                fileSize: 1024,
                env: ModrinthIndexFileEnv(client: "required", server: nil),
                source: .modrinth
            ),
            ModrinthIndexFile(
                path: "mods/jei.jar",
                hashes: ModrinthIndexFileHashes(from: ["sha1": "def"]),
                downloads: ["https://example.com/jei.jar"],
                fileSize: 2048,
                env: nil,
                source: .curseforge,
                curseForgeProjectId: 238222,
                curseForgeFileId: 4567890
            ),
        ]

        let index = ModrinthIndex(
            formatVersion: 1,
            game: "minecraft",
            versionId: "1.0.0",
            name: "Full Pack",
            summary: "A pack with files",
            files: files,
            dependencies: ModrinthIndexDependencies(
                minecraft: "1.20.1",
                forgeLoader: nil,
                fabricLoader: "0.14.21",
                quiltLoader: nil,
                neoforgeLoader: nil,
                forge: nil,
                fabric: nil,
                quilt: nil,
                neoforge: nil,
                dependencies: nil
            )
        )

        let data = try JSONEncoder().encode(index)
        let decoded = try JSONDecoder().decode(ModrinthIndex.self, from: data)

        XCTAssertEqual(decoded.files.count, 2)
        XCTAssertEqual(decoded.files[0].env?.client, "required")
        XCTAssertEqual(decoded.files[1].curseForgeProjectId, 238222)
        XCTAssertEqual(decoded.name, "Full Pack")
    }

    func testModrinthIndex_codable_withDependencies() throws {
        let deps = ModrinthIndexDependencies(
            minecraft: "1.21",
            forgeLoader: "47.3.0",
            fabricLoader: nil,
            quiltLoader: nil,
            neoforgeLoader: nil,
            forge: "47.3.0",
            fabric: nil,
            quilt: nil,
            neoforge: nil,
            dependencies: [
                ModrinthIndexProjectDependency(
                    projectId: "abc123",
                    versionId: "def456",
                    dependencyType: "required",
                ),
            ]
        )

        let index = ModrinthIndex(
            formatVersion: 1,
            game: "minecraft",
            versionId: "2.0.0",
            name: "Dep Pack",
            summary: nil,
            files: [],
            dependencies: deps
        )

        let data = try JSONEncoder().encode(index)
        let decoded = try JSONDecoder().decode(ModrinthIndex.self, from: data)

        XCTAssertEqual(decoded.dependencies.forgeLoader, "47.3.0")
        XCTAssertEqual(decoded.dependencies.dependencies?.count, 1)
        XCTAssertEqual(decoded.dependencies.dependencies?.first?.projectId, "abc123")
        XCTAssertNil(decoded.summary)
    }

    // MARK: - ModrinthIndexDependencies all loader types

    func testModrinthIndexDependencies_allLoaders() throws {
        let deps = ModrinthIndexDependencies(
            minecraft: "1.20.1",
            forgeLoader: "47.2.0",
            fabricLoader: "0.14.21",
            quiltLoader: "0.22.0",
            neoforgeLoader: "21.0.0",
            forge: "47.2.0",
            fabric: "0.14.21",
            quilt: "0.22.0",
            neoforge: "21.0.0",
            dependencies: nil
        )

        let data = try JSONEncoder().encode(deps)
        let decoded = try JSONDecoder().decode(ModrinthIndexDependencies.self, from: data)

        XCTAssertEqual(decoded.forgeLoader, "47.2.0")
        XCTAssertEqual(decoded.fabricLoader, "0.14.21")
        XCTAssertEqual(decoded.quiltLoader, "0.22.0")
        XCTAssertEqual(decoded.neoforgeLoader, "21.0.0")
        XCTAssertEqual(decoded.forge, "47.2.0")
        XCTAssertEqual(decoded.fabric, "0.14.21")
        XCTAssertEqual(decoded.quilt, "0.22.0")
        XCTAssertEqual(decoded.neoforge, "21.0.0")
    }

    func testModrinthIndexDependencies_decode_fromJSON() throws {
        let json = Data("""
        {
            "minecraft": "1.20.1",
            "forge-loader": "47.2.0",
            "fabric-loader": "0.14.21",
            "quilt-loader": "0.22.0",
            "neoforge-loader": "21.0.0"
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(ModrinthIndexDependencies.self, from: json)

        XCTAssertEqual(decoded.minecraft, "1.20.1")
        XCTAssertEqual(decoded.forgeLoader, "47.2.0")
        XCTAssertEqual(decoded.fabricLoader, "0.14.21")
        XCTAssertEqual(decoded.quiltLoader, "0.22.0")
        XCTAssertEqual(decoded.neoforgeLoader, "21.0.0")
    }

    // MARK: - ModrinthIndexInfo with CurseForge source

    func testModrinthIndexInfo_curseforgeSource() {
        let info = ModrinthIndexInfo(
            gameVersion: "1.20.1",
            loaderType: "forge",
            loaderVersion: "47.2.0",
            modPackName: "CF Pack",
            modPackVersion: "1.0",
            summary: nil,
            files: [],
            dependencies: [],
            source: .curseforge
        )

        XCTAssertEqual(info.source, .curseforge)
        XCTAssertEqual(info.modPackName, "CF Pack")
        XCTAssertEqual(info.gameVersion, "1.20.1")
    }

    func testModrinthIndexInfo_withFiles() {
        let file = ModrinthIndexFile(
            path: "mods/test.jar",
            hashes: ModrinthIndexFileHashes(from: ["sha1": "abc"]),
            downloads: ["https://example.com/test.jar"],
            fileSize: 1024
        )
        let info = ModrinthIndexInfo(
            gameVersion: "1.21",
            loaderType: "fabric",
            loaderVersion: "0.14.21",
            modPackName: "Pack",
            modPackVersion: "1.0",
            summary: "Test",
            files: [file],
            dependencies: [],
            source: .modrinth
        )

        XCTAssertEqual(info.files.count, 1)
        XCTAssertEqual(info.files[0].path, "mods/test.jar")
    }
}
