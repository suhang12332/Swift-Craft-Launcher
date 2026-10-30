//
//  CommonServiceModLoaderTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class CommonServiceModLoaderTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, from jsonObject: Any) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: jsonObject)
        return try JSONDecoder().decode(type, from: data)
    }

    func testGenerateFabricClasspath_includesAllLibraries() throws {
        let libJson: [String: Any] = [
            "name": "net.fabricmc:fabric-loader:0.14.21",
            "include_in_classpath": true,
            "downloadable": true,
        ]
        let loaderJson: [String: Any] = [
            "mainClass": "Main",
            "arguments": [:],
            "libraries": [libJson],
        ]
        let loader = try decode(ModrinthLoader.self, from: loaderJson)
        let librariesDir = URL(fileURLWithPath: "/tmp/libraries")

        let classpath = CommonService.generateFabricClasspath(from: loader, librariesDir: librariesDir)

        XCTAssertTrue(classpath.contains("net/fabricmc/fabric-loader/0.14.21"))
        XCTAssertTrue(classpath.contains("fabric-loader-0.14.21.jar"))
    }

    func testGenerateFabricClasspath_multipleLibraries() throws {
        let lib1Json: [String: Any] = [
            "name": "net.fabricmc:fabric-loader:0.14.21",
            "include_in_classpath": true,
            "downloadable": true,
        ]
        let lib2Json: [String: Any] = [
            "name": "net.fabricmc:fabric-api:0.87.0",
            "include_in_classpath": true,
            "downloadable": true,
        ]
        let loaderJson: [String: Any] = [
            "mainClass": "Main",
            "arguments": [:],
            "libraries": [lib1Json, lib2Json],
        ]
        let loader = try decode(ModrinthLoader.self, from: loaderJson)
        let librariesDir = URL(fileURLWithPath: "/tmp/libraries")

        let classpath = CommonService.generateFabricClasspath(from: loader, librariesDir: librariesDir)

        let components = classpath.components(separatedBy: ":")
        XCTAssertEqual(components.count, 2)
    }

    func testGenerateFabricClasspath_emptyLibraries() throws {
        let loaderJson: [String: Any] = [
            "mainClass": "Main",
            "arguments": [:],
            "libraries": [],
        ]
        let loader = try decode(ModrinthLoader.self, from: loaderJson)
        let librariesDir = URL(fileURLWithPath: "/tmp/libraries")

        let classpath = CommonService.generateFabricClasspath(from: loader, librariesDir: librariesDir)

        XCTAssertTrue(classpath.isEmpty)
    }

    func testGenerateFabricClasspath_usesNameNotArtifactPath() throws {
        let libJson: [String: Any] = [
            "name": "net.fabricmc:fabric-loader:0.14.21",
            "include_in_classpath": false,
            "downloadable": true,
        ]
        let loaderJson: [String: Any] = [
            "mainClass": "Main",
            "arguments": [:],
            "libraries": [libJson],
        ]
        let loader = try decode(ModrinthLoader.self, from: loaderJson)
        let librariesDir = URL(fileURLWithPath: "/tmp/libraries")

        let classpath = CommonService.generateFabricClasspath(from: loader, librariesDir: librariesDir)

        XCTAssertTrue(classpath.contains("fabric-loader-0.14.21.jar"))
    }

    func testGenerateClasspath_filtersNonClasspathLibraries() throws {
        let lib1Json: [String: Any] = [
            "name": "test:lib:1.0",
            "include_in_classpath": true,
            "downloadable": true,
            "downloads": [
                "artifact": ["path": "a/b/c.jar", "sha1": "abc", "size": 100, "url": ""],
            ],
        ]
        let lib2Json: [String: Any] = [
            "name": "test:lib2:1.0",
            "include_in_classpath": false,
            "downloadable": true,
            "downloads": [
                "artifact": ["path": "d/e/f.jar", "sha1": "def", "size": 100, "url": ""],
            ],
        ]
        let loaderJson: [String: Any] = [
            "mainClass": "Main",
            "arguments": [:],
            "libraries": [lib1Json, lib2Json],
        ]
        let loader = try decode(ModrinthLoader.self, from: loaderJson)
        let librariesDir = URL(fileURLWithPath: "/tmp/libraries")

        let classpath = CommonService.generateClasspath(from: loader, librariesDir: librariesDir)

        XCTAssertTrue(classpath.contains("a/b/c.jar"))
        XCTAssertFalse(classpath.contains("d/e/f.jar"))
    }

    func testGenerateClasspath_filtersNilDownloads() throws {
        let libJson: [String: Any] = [
            "name": "test:lib:1.0",
            "include_in_classpath": true,
            "downloadable": true,
        ]
        let loaderJson: [String: Any] = [
            "mainClass": "Main",
            "arguments": [:],
            "libraries": [libJson],
        ]
        let loader = try decode(ModrinthLoader.self, from: loaderJson)
        let librariesDir = URL(fileURLWithPath: "/tmp/libraries")

        let classpath = CommonService.generateClasspath(from: loader, librariesDir: librariesDir)

        XCTAssertTrue(classpath.isEmpty)
    }

    func testGenerateClasspath_filtersNilArtifactPath() throws {
        let libJson: [String: Any] = [
            "name": "test:lib:1.0",
            "include_in_classpath": true,
            "downloadable": true,
            "downloads": [
                "artifact": ["sha1": "abc", "size": 100, "url": ""],
            ],
        ]
        let loaderJson: [String: Any] = [
            "mainClass": "Main",
            "arguments": [:],
            "libraries": [libJson],
        ]
        let loader = try decode(ModrinthLoader.self, from: loaderJson)
        let librariesDir = URL(fileURLWithPath: "/tmp/libraries")

        let classpath = CommonService.generateClasspath(from: loader, librariesDir: librariesDir)

        XCTAssertTrue(classpath.isEmpty)
    }

    func testMavenCoordinateToRelativePathForURL_standard() {
        let result = CommonService.mavenCoordinateToRelativePathForURL("org.example:lib:1.0")
        XCTAssertEqual(result, "org/example/lib/1.0/lib-1.0.jar")
    }

    func testMavenCoordinateToRelativePathForURL_withClassifier() {
        let result = CommonService.mavenCoordinateToRelativePathForURL("org.example:lib:1.0:natives-macos")
        XCTAssertEqual(result, "org/example/lib/1.0/lib-1.0-natives-macos.jar")
    }

    func testMavenCoordinateToRelativePathForURL_withAtSymbol() {
        let result = CommonService.mavenCoordinateToRelativePathForURL("org.example:lib:1.0@lzma")
        XCTAssertTrue(result.contains("lib-1.0.lzma"))
    }

    func testMavenCoordinateToRelativePathForURL_invalid_returnsOriginal() {
        let result = CommonService.mavenCoordinateToRelativePathForURL("invalid")
        XCTAssertEqual(result, "invalid")
    }

    func testMavenCoordinateToURL_standard() {
        let baseURL = URL(fileURLWithPath: "/tmp/libraries")
        let result = CommonService.mavenCoordinateToURL("org.example:lib:1.0", baseURL: baseURL)
        XCTAssertTrue(result.path.contains("org/example/lib/1.0/lib-1.0.jar"))
    }

    func testMavenCoordinateToURL_withClassifier() {
        let baseURL = URL(fileURLWithPath: "/tmp/libraries")
        let result = CommonService.mavenCoordinateToURL("org.example:lib:1.0:natives-macos", baseURL: baseURL)
        XCTAssertTrue(result.path.contains("lib-1.0-natives-macos.jar"))
    }

    func testMavenCoordinateToURL_withUrl() {
        let lib = ModrinthLoaderLibrary(
            downloads: nil,
            name: "org.example:lib:1.0",
            includeInClasspath: true,
            downloadable: true,
        )
        var libWithUrl = lib
        libWithUrl.url = URL(fileURLWithPath: "/tmp/repo")

        let result = CommonService.mavenCoordinateToURL(lib: libWithUrl)

        guard let result else {
            return XCTFail("Expected non-nil URL")
        }
        XCTAssertTrue(result.path.contains("org/example/lib/1.0/lib-1.0.jar"))
    }

    func testMavenCoordinateToURL_nilUrl() {
        let lib = ModrinthLoaderLibrary(
            downloads: nil,
            name: "org.example:lib:1.0",
            includeInClasspath: true,
            downloadable: true,
        )

        let result = CommonService.mavenCoordinateToURL(lib: lib)

        XCTAssertNil(result)
    }

    func testProcessGameVersionPlaceholders_replacesMultiple() throws {
        let libJson: [String: Any] = [
            "name": "net.fabricmc:fabric-loom:${modrinth.gameVersion}",
            "include_in_classpath": true,
            "downloadable": true,
        ]
        let loaderJson: [String: Any] = [
            "mainClass": "Main",
            "arguments": [:],
            "libraries": [libJson, libJson],
        ]
        let loader = try decode(ModrinthLoader.self, from: loaderJson)

        let result = CommonService.processGameVersionPlaceholders(loader: loader, gameVersion: "1.21.1")

        for lib in result.libraries {
            XCTAssertEqual(lib.name, "net.fabricmc:fabric-loom:1.21.1")
        }
    }

    func testProcessGameVersionPlaceholders_preservesNonPlaceholder() throws {
        let libJson: [String: Any] = [
            "name": "net.fabricmc:fabric-loader:0.14.21",
            "include_in_classpath": true,
            "downloadable": true,
        ]
        let loaderJson: [String: Any] = [
            "mainClass": "Main",
            "arguments": [:],
            "libraries": [libJson],
        ]
        let loader = try decode(ModrinthLoader.self, from: loaderJson)

        let result = CommonService.processGameVersionPlaceholders(loader: loader, gameVersion: "1.20.1")

        XCTAssertEqual(result.libraries.first?.name, "net.fabricmc:fabric-loader:0.14.21")
    }

    func testProcessGameVersionPlaceholders_emptyLibraries() throws {
        let loaderJson: [String: Any] = [
            "mainClass": "Main",
            "arguments": [:],
            "libraries": [],
        ]
        let loader = try decode(ModrinthLoader.self, from: loaderJson)

        let result = CommonService.processGameVersionPlaceholders(loader: loader, gameVersion: "1.20.1")

        XCTAssertTrue(result.libraries.isEmpty)
    }

    func testProcessGameVersionPlaceholders_preservesMainClass() throws {
        let loaderJson: [String: Any] = [
            "mainClass": "net.fabricmc.loader.impl.launch.knot.KnotClient",
            "arguments": [:],
            "libraries": [],
        ]
        let loader = try decode(ModrinthLoader.self, from: loaderJson)

        let result = CommonService.processGameVersionPlaceholders(loader: loader, gameVersion: "1.20.1")

        XCTAssertEqual(result.mainClass, "net.fabricmc.loader.impl.launch.knot.KnotClient")
    }

    private func loaderInfo(_ id: String, stable: Bool = false) -> [String: Any] {
        [
            "id": id,
            "url": "https://launcher-meta.modrinth.com/test/\(id)",
            "stable": stable,
        ]
    }

    func testResolveLoaderVersions_quilt_resolvesVersionGroups() throws {
        let manifestJSON: [String: Any] = [
            "gameVersions": [
                ["id": "1.21.1", "stable": true, "versionGroup": "v1", "loaders": []],
                ["id": "26.4-snapshot-6", "stable": false, "versionGroup": "v2", "loaders": []],
            ],
            "versionGroups": [
                [
                    "id": "v1",
                    "loaders": [
                        loaderInfo("0.30.1"),
                        loaderInfo("0.31.0-beta.1"),
                        loaderInfo("0.29.0-pre1"),
                    ],
                ],
                ["id": "v2", "loaders": [loaderInfo("0.30.1")]],
            ],
        ]
        let manifest = try decode(ModrinthLoaderVersion.self, from: manifestJSON)

        let versions = CommonService.resolveLoaderVersions(from: manifest, type: "quilt")

        // Quilt keeps only concrete release numbers for both game and loader versions,
        // because launcher-meta marks every Quilt entry as unstable.
        XCTAssertEqual(versions.count, 1)
        XCTAssertEqual(versions.first?.id, "1.21.1")
        XCTAssertEqual(versions.first?.loaders.map(\.id), ["0.30.1"])
    }

    func testResolveLoaderVersions_fabric_appliesUniversalLoaders() throws {
        let manifestJSON: [String: Any] = [
            "gameVersions": [
                [
                    "id": "${modrinth.gameVersion}",
                    "stable": true,
                    "loaders": [loaderInfo("0.16.9", stable: true)],
                ],
                ["id": "1.21.1", "stable": true, "loaders": []],
            ],
        ]
        let manifest = try decode(ModrinthLoaderVersion.self, from: manifestJSON)

        let versions = CommonService.resolveLoaderVersions(from: manifest, type: "fabric")

        // The placeholder entry is dropped, and the real version reuses its loaders.
        XCTAssertEqual(versions.count, 1)
        XCTAssertEqual(versions.first?.id, "1.21.1")
        XCTAssertEqual(versions.first?.loaders.map(\.id), ["0.16.9"])
    }

    func testResolveLoaderVersions_filtersGameVersions() throws {
        let manifestJSON: [String: Any] = [
            "gameVersions": [
                ["id": "1.21.1", "stable": true, "loaders": [loaderInfo("21.1.0", stable: true)]],
                ["id": "26.4-snapshot-6", "stable": false, "loaders": [loaderInfo("21.2.0", stable: true)]],
                ["id": "26.1-pre-3", "stable": true, "loaders": [loaderInfo("21.3.0", stable: true)]],
            ],
        ]
        let manifest = try decode(ModrinthLoaderVersion.self, from: manifestJSON)

        // Forge trusts `stable`, while NeoForge keeps release numbers only.
        XCTAssertEqual(
            CommonService.resolveLoaderVersions(from: manifest, type: "forge").map(\.id),
            ["1.21.1", "26.1-pre-3"],
        )
        XCTAssertEqual(CommonService.resolveLoaderVersions(from: manifest, type: "neo").map(\.id), ["1.21.1"])
    }

    func testResolveLoaderVersions_neoforge_filtersLetterLoaderVersions() throws {
        let manifestJSON: [String: Any] = [
            "gameVersions": [
                [
                    "id": "1.21.1",
                    "stable": true,
                    "loaders": [
                        loaderInfo("21.1.265", stable: false),
                        loaderInfo("21.1.0-beta", stable: false),
                        loaderInfo("0.25w14craftmine.3-beta", stable: false),
                    ],
                ],
            ],
        ]
        let manifest = try decode(ModrinthLoaderVersion.self, from: manifestJSON)

        let versions = CommonService.resolveLoaderVersions(from: manifest, type: "neo")

        XCTAssertEqual(versions.first?.loaders.map(\.id), ["21.1.265"])
    }

    func testResolveLoaderVersions_quilt_keepsStableVersionsWhileNeoUsesReleaseNumbers() throws {
        let manifestJSON: [String: Any] = [
            "gameVersions": [
                ["id": "1.21.1", "stable": true, "versionGroup": "v1", "loaders": []],
                ["id": "26.3-rc-3", "stable": true, "versionGroup": "v1", "loaders": []],
            ],
            "versionGroups": [
                ["id": "v1", "loaders": [loaderInfo("0.30.1")]],
            ],
        ]
        let manifest = try decode(ModrinthLoaderVersion.self, from: manifestJSON)

        // Quilt trusts the stability flag; NeoForge ignores it and keeps release numbers only.
        XCTAssertEqual(
            CommonService.resolveLoaderVersions(from: manifest, type: "quilt").map(\.id),
            ["1.21.1", "26.3-rc-3"],
        )
        XCTAssertEqual(CommonService.resolveLoaderVersions(from: manifest, type: "neo").map(\.id), ["1.21.1"])
    }
}
