//
//  ModrinthModelTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CFModrinthAdapterKit
@testable import SwiftCraftLauncher
import XCTest

final class ModrinthModelTests: XCTestCase {
    func testModrinthProjectDetail_codable_roundTrip() throws {
        let detail = makeDetail(
            id: "proj-1",
            slug: "my-mod",
            title: "My Mod",
            description: "A great mod",
            categories: ["fabric", "library"],
            projectType: "mod",
            downloads: 1234,
            team: "Team1",
        )

        let encoded = try JSONEncoder().encode(detail)
        let decoded = try JSONDecoder().decode(ModrinthProjectDetail.self, from: encoded)

        XCTAssertEqual(decoded.id, "proj-1")
        XCTAssertEqual(decoded.slug, "my-mod")
        XCTAssertEqual(decoded.title, "My Mod")
        XCTAssertEqual(decoded.description, "A great mod")
        XCTAssertEqual(decoded.categories, ["fabric", "library"])
        XCTAssertEqual(decoded.projectType, "mod")
        XCTAssertEqual(decoded.downloads, 1234)
        XCTAssertEqual(decoded.team, "Team1")
    }

    func testModrinthProjectDetail_codable_withNilFields() throws {
        let detail = makeDetail(
            id: "proj-nil",
            slug: "nil-fields",
            title: "Nil Fields",
            description: "desc",
            categories: [],
            projectType: "mod",
            downloads: 0,
            team: "team",
        )

        let encoded = try JSONEncoder().encode(detail)
        let decoded = try JSONDecoder().decode(ModrinthProjectDetail.self, from: encoded)

        XCTAssertNil(decoded.additionalCategories)
        XCTAssertNil(decoded.issuesUrl)
        XCTAssertNil(decoded.sourceUrl)
        XCTAssertNil(decoded.wikiUrl)
        XCTAssertNil(decoded.discordUrl)
        XCTAssertNil(decoded.iconUrl)
        XCTAssertNil(decoded.type)
        XCTAssertNil(decoded.fileName)
        XCTAssertNil(decoded.license)
    }

    func testModrinthProjectDetail_codable_withAllFields() throws {
        let license = License(id: "mit", name: "MIT", url: "https://opensource.org/licenses/MIT")
        let detail = ModrinthProjectDetail(
            slug: "full-mod",
            title: "Full Mod",
            description: "Full description",
            categories: ["fabric", "library"],
            clientSide: "required",
            serverSide: "optional",
            body: "Body text",
            additionalCategories: ["utility"],
            issuesUrl: "https://github.com/issues",
            sourceUrl: "https://github.com/source",
            wikiUrl: "https://wiki.example.com",
            discordUrl: "https://discord.gg/test",
            projectType: "mod",
            downloads: 5000,
            iconUrl: "https://icon.png",
            id: "full-id",
            team: "FullTeam",
            published: Date(timeIntervalSince1970: 1_700_000_000),
            updated: Date(timeIntervalSince1970: 1_700_100_000),
            followers: 42,
            license: license,
            versions: ["1.20.1", "1.21"],
            gameVersions: ["1.20.1", "1.21"],
            loaders: ["fabric", "quilt"],
            type: nil,
            fileName: "full-mod-1.0.jar",
        )

        let encoded = try JSONEncoder().encode(detail)
        let decoded = try JSONDecoder().decode(ModrinthProjectDetail.self, from: encoded)

        XCTAssertEqual(decoded.additionalCategories, ["utility"])
        XCTAssertEqual(decoded.issuesUrl, "https://github.com/issues")
        XCTAssertEqual(decoded.sourceUrl, "https://github.com/source")
        XCTAssertEqual(decoded.wikiUrl, "https://wiki.example.com")
        XCTAssertEqual(decoded.discordUrl, "https://discord.gg/test")
        XCTAssertEqual(decoded.iconUrl, "https://icon.png")
        XCTAssertEqual(decoded.followers, 42)
        XCTAssertEqual(decoded.versions, ["1.20.1", "1.21"])
        XCTAssertEqual(decoded.loaders, ["fabric", "quilt"])
        XCTAssertEqual(decoded.fileName, "full-mod-1.0.jar")
        XCTAssertEqual(decoded.license?.id, "mit")
        XCTAssertEqual(decoded.license?.name, "MIT")
    }

    func testModrinthProjectDetail_equatable() {
        let a = makeDetail(id: "id", slug: "s", title: "T", description: "d", categories: [], projectType: "mod", downloads: 0, team: "t")
        let b = makeDetail(id: "id", slug: "s", title: "T", description: "d", categories: [], projectType: "mod", downloads: 0, team: "t")
        let c = makeDetail(id: "id2", slug: "s", title: "T", description: "d", categories: [], projectType: "mod", downloads: 0, team: "t")

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testModrinthProjectDetail_hashable() {
        let a = makeDetail(id: "id", slug: "s", title: "T", description: "d", categories: [], projectType: "mod", downloads: 0, team: "t")
        let b = makeDetail(id: "id", slug: "s", title: "T", description: "d", categories: [], projectType: "mod", downloads: 0, team: "t")

        var set = Set<ModrinthProjectDetail>()
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 1)
    }

    func testModrinthProjectDetail_decode_invalidJSON() {
        let json = Data("not valid".utf8)
        let decoded = try? JSONDecoder().decode(ModrinthProjectDetail.self, from: json)
        XCTAssertNil(decoded)
    }

    func testModrinthProjectDetail_decode_missingRequiredField() {
        let json = Data("""
        {"slug": "s", "title": "T"}
        """.utf8)
        let decoded = try? JSONDecoder().decode(ModrinthProjectDetail.self, from: json)
        XCTAssertNil(decoded)
    }

    func testModrinthProjectDetailVersion_codable_roundTrip() throws {
        let version = makeVersion(
            id: "ver-1",
            projectId: "proj-1",
            name: "Version 1.0",
            versionNumber: "1.0.0",
            gameVersions: ["1.20.1"],
            loaders: ["fabric"],
        )

        let encoded = try JSONEncoder().encode(version)
        let decoded = try JSONDecoder().decode(ModrinthProjectDetailVersion.self, from: encoded)

        XCTAssertEqual(decoded.id, "ver-1")
        XCTAssertEqual(decoded.projectId, "proj-1")
        XCTAssertEqual(decoded.name, "Version 1.0")
        XCTAssertEqual(decoded.versionNumber, "1.0.0")
        XCTAssertEqual(decoded.gameVersions, ["1.20.1"])
        XCTAssertEqual(decoded.loaders, ["fabric"])
    }

    func testModrinthProjectDetailVersion_codable_withDependencies() throws {
        let deps = [
            ModrinthVersionDependency(projectId: "dep-1", versionId: "ver-dep-1", dependencyType: "required"),
            ModrinthVersionDependency(projectId: "dep-2", versionId: nil, dependencyType: "optional"),
        ]
        let version = makeVersion(
            id: "ver-dep",
            projectId: "proj",
            name: "With Deps",
            versionNumber: "1.0",
            gameVersions: ["1.20"],
            loaders: ["fabric"],
            dependencies: deps,
        )

        let encoded = try JSONEncoder().encode(version)
        let decoded = try JSONDecoder().decode(ModrinthProjectDetailVersion.self, from: encoded)

        XCTAssertEqual(decoded.dependencies.count, 2)
        XCTAssertEqual(decoded.dependencies[0].projectId, "dep-1")
        XCTAssertEqual(decoded.dependencies[0].dependencyType, "required")
        XCTAssertNil(decoded.dependencies[1].versionId)
        XCTAssertEqual(decoded.dependencies[1].dependencyType, "optional")
    }

    func testModrinthProjectDetailVersion_codable_withFiles() throws {
        let file = ModrinthVersionFile(
            hashes: ModrinthVersionFileHashes(sha512: "sha512hash", sha1: "sha1hash"),
            url: "https://example.com/mod.jar",
            filename: "mod.jar",
            primary: true,
            size: 1024,
            fileType: "jar",
        )
        let version = makeVersion(
            id: "ver-file",
            projectId: "proj",
            name: "With File",
            versionNumber: "1.0",
            gameVersions: ["1.20"],
            loaders: ["fabric"],
            files: [file],
        )

        let encoded = try JSONEncoder().encode(version)
        let decoded = try JSONDecoder().decode(ModrinthProjectDetailVersion.self, from: encoded)

        XCTAssertEqual(decoded.files.count, 1)
        XCTAssertEqual(decoded.files[0].filename, "mod.jar")
        XCTAssertEqual(decoded.files[0].hashes.sha1, "sha1hash")
        XCTAssertTrue(decoded.files[0].primary)
        XCTAssertEqual(decoded.files[0].size, 1024)
        XCTAssertEqual(decoded.files[0].fileType, "jar")
    }

    func testModrinthProjectDetailVersion_equatable() {
        let a = makeVersion(id: "v1", projectId: "p", name: "V1", versionNumber: "1.0", gameVersions: [], loaders: [])
        let b = makeVersion(id: "v1", projectId: "p", name: "V1", versionNumber: "1.0", gameVersions: [], loaders: [])
        let c = makeVersion(id: "v2", projectId: "p", name: "V2", versionNumber: "2.0", gameVersions: [], loaders: [])

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testModrinthVersionFile_codable_roundTrip() throws {
        let file = ModrinthVersionFile(
            hashes: ModrinthVersionFileHashes(sha512: "abc512", sha1: "abc1"),
            url: "https://example.com/file.jar",
            filename: "file.jar",
            primary: true,
            size: 2048,
            fileType: "jar",
        )

        let encoded = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(ModrinthVersionFile.self, from: encoded)

        XCTAssertEqual(decoded.hashes.sha512, "abc512")
        XCTAssertEqual(decoded.hashes.sha1, "abc1")
        XCTAssertEqual(decoded.url, "https://example.com/file.jar")
        XCTAssertEqual(decoded.filename, "file.jar")
        XCTAssertTrue(decoded.primary)
        XCTAssertEqual(decoded.size, 2048)
        XCTAssertEqual(decoded.fileType, "jar")
    }

    func testModrinthVersionFile_codable_nilFileType() throws {
        let file = ModrinthVersionFile(
            hashes: ModrinthVersionFileHashes(sha512: "abc512", sha1: "abc1"),
            url: "https://example.com/file",
            filename: "file",
            primary: false,
            size: 0,
            fileType: nil,
        )

        let encoded = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(ModrinthVersionFile.self, from: encoded)

        XCTAssertNil(decoded.fileType)
    }

    func testModrinthVersionFileHashes_codable_roundTrip() throws {
        let hashes = ModrinthVersionFileHashes(sha512: "sha512val", sha1: "sha1val")
        let encoded = try JSONEncoder().encode(hashes)
        let decoded = try JSONDecoder().decode(ModrinthVersionFileHashes.self, from: encoded)

        XCTAssertEqual(decoded.sha512, "sha512val")
        XCTAssertEqual(decoded.sha1, "sha1val")
    }

    func testModrinthVersionDependency_codable_roundTrip() throws {
        let dep = ModrinthVersionDependency(projectId: "p1", versionId: "v1", dependencyType: "required")
        let encoded = try JSONEncoder().encode(dep)
        let decoded = try JSONDecoder().decode(ModrinthVersionDependency.self, from: encoded)

        XCTAssertEqual(decoded.projectId, "p1")
        XCTAssertEqual(decoded.versionId, "v1")
        XCTAssertEqual(decoded.dependencyType, "required")
    }

    func testModrinthVersionDependency_codable_nilIds() throws {
        let dep = ModrinthVersionDependency(projectId: nil, versionId: nil, dependencyType: "incompatible")
        let encoded = try JSONEncoder().encode(dep)
        let decoded = try JSONDecoder().decode(ModrinthVersionDependency.self, from: encoded)

        XCTAssertNil(decoded.projectId)
        XCTAssertNil(decoded.versionId)
        XCTAssertEqual(decoded.dependencyType, "incompatible")
    }

    func testModrinthProject_codable_roundTrip() throws {
        let project = ModrinthProject(
            projectId: "proj-1",
            projectType: "mod",
            slug: "my-mod",
            author: "Author",
            title: "My Mod",
            description: "A mod",
            categories: ["fabric"],
            displayCategories: ["library"],
            versions: ["1.20.1"],
            downloads: 100,
            follows: 10,
            iconUrl: "https://icon.png",
            license: "MIT",
            clientSide: "required",
            serverSide: "optional",
            fileName: "my-mod.jar",
        )

        let encoded = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(ModrinthProject.self, from: encoded)

        XCTAssertEqual(decoded.projectId, "proj-1")
        XCTAssertEqual(decoded.projectType, "mod")
        XCTAssertEqual(decoded.slug, "my-mod")
        XCTAssertEqual(decoded.author, "Author")
        XCTAssertEqual(decoded.title, "My Mod")
        XCTAssertEqual(decoded.iconUrl, "https://icon.png")
        XCTAssertEqual(decoded.fileName, "my-mod.jar")
    }

    func testLicense_codable_roundTrip() throws {
        let license = License(id: "mit", name: "MIT License", url: "https://opensource.org/licenses/MIT")
        let encoded = try JSONEncoder().encode(license)
        let decoded = try JSONDecoder().decode(License.self, from: encoded)

        XCTAssertEqual(decoded.id, "mit")
        XCTAssertEqual(decoded.name, "MIT License")
        XCTAssertEqual(decoded.url, "https://opensource.org/licenses/MIT")
    }

    func testLicense_codable_nilUrl() throws {
        let license = License(id: "apache-2.0", name: "Apache 2.0", url: nil)
        let encoded = try JSONEncoder().encode(license)
        let decoded = try JSONDecoder().decode(License.self, from: encoded)

        XCTAssertNil(decoded.url)
    }

    func testLicense_equatable() {
        let a = License(id: "mit", name: "MIT", url: nil)
        let b = License(id: "mit", name: "MIT", url: nil)
        let c = License(id: "apache", name: "Apache", url: nil)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testLicense_hashable() {
        let a = License(id: "mit", name: "MIT", url: nil)
        let b = License(id: "mit", name: "MIT", url: nil)

        var set = Set<License>()
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 1)
    }

    func testModrinthProjectDependency_codable_roundTrip() throws {
        let version = makeVersion(id: "v1", projectId: "p1", name: "V1", versionNumber: "1.0", gameVersions: [], loaders: [])
        let dep = ModrinthProjectDependency(projects: [version])

        let encoded = try JSONEncoder().encode(dep)
        let decoded = try JSONDecoder().decode(ModrinthProjectDependency.self, from: encoded)

        XCTAssertEqual(decoded.projects.count, 1)
        XCTAssertEqual(decoded.projects[0].id, "v1")
    }

    func testModrinthResult_codable_roundTrip() throws {
        let project = ModrinthProject(
            projectId: "p1",
            projectType: "mod",
            slug: "s",
            author: "a",
            title: "T",
            description: "d",
            categories: [],
            displayCategories: [],
            versions: [],
            downloads: 10,
            follows: 5,
            iconUrl: nil,
            license: "",
            clientSide: "required",
            serverSide: "optional",
            fileName: nil,
        )
        let result = ModrinthResult(hits: [project], offset: 0, limit: 10, totalHits: 100)

        let encoded = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(ModrinthResult.self, from: encoded)

        XCTAssertEqual(decoded.hits.count, 1)
        XCTAssertEqual(decoded.offset, 0)
        XCTAssertEqual(decoded.limit, 10)
        XCTAssertEqual(decoded.totalHits, 100)
    }

    func testModrinthLoaderLibrary_withDownloads() throws {
        let json = """
        {
            "name": "test:lib:1.0",
            "include_in_classpath": true,
            "downloadable": true,
            "downloads": {
                "artifact": {
                    "path": "test/lib-1.0.jar",
                    "sha1": "abc123",
                    "size": 1024,
                    "url": "https://maven.example.com/lib-1.0.jar"
                }
            }
        }
        """
        let lib = try JSONDecoder().decode(ModrinthLoaderLibrary.self, from: Data(json.utf8))

        XCTAssertNotNil(lib.downloads)
        XCTAssertEqual(lib.downloads?.artifact.path, "test/lib-1.0.jar")
        XCTAssertEqual(lib.downloads?.artifact.sha1, "abc123")
        XCTAssertEqual(lib.downloads?.artifact.size, 1024)
    }

    // swiftlint:disable:next function_parameter_count
    private func makeDetail(
        id: String,
        slug: String,
        title: String,
        description: String,
        categories: [String],
        additionalCategories: [String]? = nil,
        projectType: String,
        downloads: Int,
        team: String,
        license: License? = nil,
    ) -> ModrinthProjectDetail {
        ModrinthProjectDetail(
            slug: slug,
            title: title,
            description: description,
            categories: categories,
            clientSide: "required",
            serverSide: "required",
            body: "",
            additionalCategories: additionalCategories,
            issuesUrl: nil,
            sourceUrl: nil,
            wikiUrl: nil,
            discordUrl: nil,
            projectType: projectType,
            downloads: downloads,
            iconUrl: nil,
            id: id,
            team: team,
            published: Date(timeIntervalSince1970: 1_700_000_000),
            updated: Date(timeIntervalSince1970: 1_700_000_000),
            followers: 0,
            license: license,
            versions: ["1.20.1"],
            gameVersions: ["1.20.1"],
            loaders: ["fabric"],
            type: nil,
            fileName: nil,
        )
    }

    private func makeVersion(
        id: String,
        projectId: String,
        name: String,
        versionNumber: String,
        gameVersions: [String],
        loaders: [String],
        files: [ModrinthVersionFile] = [],
        dependencies: [ModrinthVersionDependency] = [],
    ) -> ModrinthProjectDetailVersion {
        ModrinthProjectDetailVersion(
            gameVersions: gameVersions,
            loaders: loaders,
            id: id,
            projectId: projectId,
            authorId: "author-1",
            featured: false,
            name: name,
            versionNumber: versionNumber,
            changelog: nil,
            changelogUrl: nil,
            datePublished: Date(timeIntervalSince1970: 1_700_000_000),
            downloads: 0,
            versionType: "release",
            status: "listed",
            requestedStatus: nil,
            files: files,
            dependencies: dependencies,
        )
    }
}
