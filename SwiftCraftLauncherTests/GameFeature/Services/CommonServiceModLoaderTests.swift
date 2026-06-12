import XCTest
@testable import SwiftCraftLauncher

final class CommonServiceModLoaderTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, from jsonObject: Any) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: jsonObject)
        return try JSONDecoder().decode(type, from: data)
    }

    // MARK: - generateFabricClasspath

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

    // MARK: - generateClasspath (Forge/NeoForge)

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

    // MARK: - mavenCoordinateToDefaultPath

    func testMavenCoordinateToDefaultPath_standard() {
        let result = CommonService.mavenCoordinateToDefaultPath("org.example:lib:1.0")
        XCTAssertEqual(result, "org/example/lib/1.0/lib-1.0.jar")
    }

    func testMavenCoordinateToDefaultPath_withClassifier() {
        let result = CommonService.mavenCoordinateToDefaultPath("org.example:lib:1.0:natives-macos")
        XCTAssertEqual(result, "org/example/lib/1.0/lib-1.0-natives-macos.jar")
    }

    func testMavenCoordinateToDefaultPath_withAtSymbol() {
        let result = CommonService.mavenCoordinateToDefaultPath("org.example:lib:1.0@lzma")
        XCTAssertTrue(result.contains("lib-1.0.lzma"))
    }

    func testMavenCoordinateToDefaultPath_invalid_returnsOriginal() {
        let result = CommonService.mavenCoordinateToDefaultPath("invalid")
        XCTAssertEqual(result, "invalid")
    }

    // MARK: - mavenCoordinateToDefaultURL

    func testMavenCoordinateToDefaultURL_standard() {
        let baseURL = URL(fileURLWithPath: "/tmp/libraries")
        let result = CommonService.mavenCoordinateToDefaultURL("org.example:lib:1.0", url: baseURL)
        XCTAssertTrue(result.path.contains("org/example/lib/1.0/lib-1.0.jar"))
    }

    func testMavenCoordinateToDefaultURL_withClassifier() {
        let baseURL = URL(fileURLWithPath: "/tmp/libraries")
        let result = CommonService.mavenCoordinateToDefaultURL("org.example:lib:1.0:natives-macos", url: baseURL)
        XCTAssertTrue(result.path.contains("lib-1.0-natives-macos.jar"))
    }

    // MARK: - mavenCoordinateToURL

    func testMavenCoordinateToURL_withUrl() throws {
        let lib = ModrinthLoaderLibrary(
            downloads: nil,
            name: "org.example:lib:1.0",
            includeInClasspath: true,
            downloadable: true
        )
        var libWithUrl = lib
        libWithUrl.url = URL(fileURLWithPath: "/tmp/repo")

        let result = CommonService.mavenCoordinateToURL(lib: libWithUrl)

        guard let result else {
            return XCTFail("Expected non-nil URL")
        }
        XCTAssertTrue(result.path.contains("org/example/lib/1.0/lib-1.0.jar"))
    }

    func testMavenCoordinateToURL_nilUrl() throws {
        let lib = ModrinthLoaderLibrary(
            downloads: nil,
            name: "org.example:lib:1.0",
            includeInClasspath: true,
            downloadable: true
        )

        let result = CommonService.mavenCoordinateToURL(lib: lib)

        XCTAssertNil(result)
    }

    // MARK: - processGameVersionPlaceholders

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
}
