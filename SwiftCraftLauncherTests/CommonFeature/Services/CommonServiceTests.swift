import XCTest
@testable import SwiftCraftLauncher

final class CommonServiceTests: XCTestCase {

    // MARK: - mavenCoordinateToRelativePath

    func testMavenCoordinateToRelativePath_threeParts() {
        let result = CommonService.mavenCoordinateToRelativePath("org.example:lib:1.0")
        XCTAssertEqual(result, "org/example/lib/1.0/lib-1.0.jar")
    }

    func testMavenCoordinateToRelativePath_fourParts() {
        let result = CommonService.mavenCoordinateToRelativePath("org.example:lib:1.0:natives-macos")
        XCTAssertEqual(result, "org/example/lib/1.0/lib-1.0-natives-macos.jar")
    }

    func testMavenCoordinateToRelativePath_fiveParts() {
        let result = CommonService.mavenCoordinateToRelativePath("org.example:lib:jar:natives-macos:1.0")
        XCTAssertEqual(result, "org/example/lib/1.0/lib-1.0-natives-macos.jar")
    }

    func testMavenCoordinateToRelativePath_twoParts_returnsNil() {
        let result = CommonService.mavenCoordinateToRelativePath("org.example:lib")
        XCTAssertNil(result)
    }

    func testMavenCoordinateToRelativePath_onePart_returnsNil() {
        let result = CommonService.mavenCoordinateToRelativePath("org.example")
        XCTAssertNil(result)
    }

    func testMavenCoordinateToRelativePath_empty_returnsNil() {
        let result = CommonService.mavenCoordinateToRelativePath("")
        XCTAssertNil(result)
    }

    // MARK: - parseMavenCoordinateWithAtSymbol

    func testParseMavenCoordinateWithAtSymbol_versionAtExtension() {
        let result = CommonService.parseMavenCoordinateWithAtSymbol("org.example:lib:1.0@lzma")
        XCTAssertTrue(result.contains("org/example/lib/1.0"))
        XCTAssertTrue(result.contains("lib-1.0.lzma"))
    }

    func testParseMavenCoordinateWithAtSymbol_simple() {
        let result = CommonService.parseMavenCoordinateWithAtSymbol("net.fabricmc:fabric-loom:0.2")
        XCTAssertTrue(result.contains("net/fabricmc/fabric-loom/0.2"))
    }

    func testParseMavenCoordinateWithAtSymbol_classifierAtExtension() {
        let result = CommonService.parseMavenCoordinateWithAtSymbol("org.example:lib:1.0:client@lzma")
        XCTAssertTrue(result.contains("lib-1.0-client.lzma"))
    }

    func testParseMavenCoordinateWithAtSymbol_tooFewParts() {
        let result = CommonService.parseMavenCoordinateWithAtSymbol("org:lib")
        XCTAssertEqual(result, "org:lib")
    }

    // MARK: - mavenCoordinateToRelativePathForURL

    func testMavenCoordinateToRelativePathForURL_standard() {
        let result = CommonService.mavenCoordinateToRelativePathForURL("org.example:lib:1.0")
        XCTAssertEqual(result, "org/example/lib/1.0/lib-1.0.jar")
    }

    func testMavenCoordinateToRelativePathForURL_withAtSymbol() {
        let result = CommonService.mavenCoordinateToRelativePathForURL("org.example:lib:1.0@jar")
        XCTAssertTrue(result.contains("lib-1.0.jar"))
    }

    func testMavenCoordinateToRelativePathForURL_invalid_returnsOriginal() {
        let result = CommonService.mavenCoordinateToRelativePathForURL("invalid")
        XCTAssertEqual(result, "invalid")
    }

    // MARK: - generateClasspath

    func testGenerateClasspath_filtersNonClasspathLibraries() {
        let lib1Json: [String: Any] = [
            "name": "test:lib:1.0",
            "include_in_classpath": true,
            "downloadable": true,
            "downloads": [
                "artifact": ["path": "a/b/c.jar", "sha1": "abc", "size": 100, "url": ""]
            ]
        ]
        let lib2Json: [String: Any] = [
            "name": "test:lib2:1.0",
            "include_in_classpath": false,
            "downloadable": true,
            "downloads": [
                "artifact": ["path": "d/e/f.jar", "sha1": "def", "size": 100, "url": ""]
            ]
        ]
        let lib3Json: [String: Any] = [
            "name": "test:lib3:1.0",
            "include_in_classpath": true,
            "downloadable": true
        ]

        let lib1 = try! JSONDecoder().decode(ModrinthLoaderLibrary.self, from: JSONSerialization.data(withJSONObject: lib1Json))
        let lib2 = try! JSONDecoder().decode(ModrinthLoaderLibrary.self, from: JSONSerialization.data(withJSONObject: lib2Json))
        let lib3 = try! JSONDecoder().decode(ModrinthLoaderLibrary.self, from: JSONSerialization.data(withJSONObject: lib3Json))

        let loaderJson: [String: Any] = [
            "mainClass": "Main",
            "arguments": [:],
            "libraries": [lib1Json, lib2Json, lib3Json]
        ]
        let loader = try! JSONDecoder().decode(ModrinthLoader.self, from: JSONSerialization.data(withJSONObject: loaderJson))

        let librariesDir = URL(fileURLWithPath: "/tmp/libraries")
        let classpath = CommonService.generateClasspath(from: loader, librariesDir: librariesDir)

        XCTAssertTrue(classpath.contains("a/b/c.jar"))
        XCTAssertFalse(classpath.contains("d/e/f.jar"))
    }

    // MARK: - processGameVersionPlaceholders

    func testProcessGameVersionPlaceholders_replacesModrinthGameVersion() {
        let libJson: [String: Any] = [
            "name": "net.fabricmc:fabric-loom:${modrinth.gameVersion}",
            "include_in_classpath": true,
            "downloadable": true
        ]
        let lib = try! JSONDecoder().decode(ModrinthLoaderLibrary.self, from: JSONSerialization.data(withJSONObject: libJson))
        let loaderJson: [String: Any] = [
            "mainClass": "Main",
            "arguments": [:],
            "libraries": [libJson]
        ]
        let loader = try! JSONDecoder().decode(ModrinthLoader.self, from: JSONSerialization.data(withJSONObject: loaderJson))

        let result = CommonService.processGameVersionPlaceholders(loader: loader, gameVersion: "1.20.1")

        XCTAssertEqual(result.libraries.first?.name, "net.fabricmc:fabric-loom:1.20.1")
    }

    func testProcessGameVersionPlaceholders_noPlaceholder() {
        let libJson: [String: Any] = [
            "name": "net.fabricmc:fabric-loom:0.14.21",
            "include_in_classpath": true,
            "downloadable": true
        ]
        let lib = try! JSONDecoder().decode(ModrinthLoaderLibrary.self, from: JSONSerialization.data(withJSONObject: libJson))
        let loaderJson2: [String: Any] = [
            "mainClass": "Main",
            "arguments": [:],
            "libraries": [libJson]
        ]
        let loader = try! JSONDecoder().decode(ModrinthLoader.self, from: JSONSerialization.data(withJSONObject: loaderJson2))

        let result = CommonService.processGameVersionPlaceholders(loader: loader, gameVersion: "1.20.1")

        XCTAssertEqual(result.libraries.first?.name, "net.fabricmc:fabric-loom:0.14.21")
    }
}
