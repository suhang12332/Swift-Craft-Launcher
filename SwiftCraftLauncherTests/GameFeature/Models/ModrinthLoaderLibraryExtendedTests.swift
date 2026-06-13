import XCTest
@testable import SwiftCraftLauncher

final class ModrinthLoaderLibraryExtendedTests: XCTestCase {

    // MARK: - CodingKeys

    func testCodingKeys_includeInClasspath() throws {
        let json = """
        {
            "name": "test:lib:1.0",
            "include_in_classpath": false,
            "downloadable": true
        }
        """
        let lib = try JSONDecoder().decode(ModrinthLoaderLibrary.self, from: Data(json.utf8))

        XCTAssertFalse(lib.includeInClasspath)
        XCTAssertTrue(lib.downloadable)
    }

    func testCodingKeys_urlField() throws {
        let json = """
        {
            "name": "test:lib:1.0",
            "include_in_classpath": true,
            "downloadable": true,
            "url": "https://example.com/lib.jar"
        }
        """
        let lib = try JSONDecoder().decode(ModrinthLoaderLibrary.self, from: Data(json.utf8))

        XCTAssertEqual(lib.url?.absoluteString, "https://example.com/lib.jar")
    }

    func testCodable_roundTrip() throws {
        let original = ModrinthLoaderLibrary(
            downloads: nil,
            name: "test:lib:1.0",
            includeInClasspath: true,
            downloadable: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModrinthLoaderLibrary.self, from: data)

        XCTAssertEqual(decoded.name, "test:lib:1.0")
        XCTAssertTrue(decoded.includeInClasspath)
        XCTAssertFalse(decoded.downloadable)
    }

    func testInit_withDownloads() {
        let lib = ModrinthLoaderLibrary(
            downloads: nil,
            name: "test:lib:1.0",
            includeInClasspath: true,
            downloadable: true
        )

        XCTAssertNil(lib.downloads)
        XCTAssertEqual(lib.name, "test:lib:1.0")
    }

    // MARK: - ModrinthLoader edge cases

    func testModrinthLoader_withAllOptionalFields() throws {
        let json = """
        {
            "mainClass": "Main",
            "arguments": {"game": ["--test"], "jvm": ["-Xmx1G"]},
            "libraries": [],
            "version": "1.0",
            "processors": [
                {"sides": ["client"], "jar": "p.jar", "classpath": [], "args": [], "outputs": {}}
            ],
            "data": {
                "mappings": {"client": "mapped-c", "server": "mapped-s"}
            }
        }
        """
        let loader = try JSONDecoder().decode(ModrinthLoader.self, from: Data(json.utf8))

        XCTAssertEqual(loader.mainClass, "Main")
        XCTAssertEqual(loader.version, "1.0")
        XCTAssertEqual(loader.processors?.count, 1)
        XCTAssertEqual(loader.data?["mappings"]?.client, "mapped-c")
        XCTAssertEqual(loader.data?["mappings"]?.server, "mapped-s")
        XCTAssertEqual(loader.arguments.game?.count, 1)
        XCTAssertEqual(loader.arguments.jvm?.count, 1)
    }

    func testModrinthLoader_minimal() throws {
        let json = """
        {
            "mainClass": "Main",
            "arguments": {"game": [], "jvm": []},
            "libraries": []
        }
        """
        let loader = try JSONDecoder().decode(ModrinthLoader.self, from: Data(json.utf8))

        XCTAssertEqual(loader.mainClass, "Main")
        XCTAssertNil(loader.version)
        XCTAssertNil(loader.processors)
        XCTAssertNil(loader.data)
        XCTAssertTrue(loader.libraries.isEmpty)
    }

    // MARK: - LoaderVersion edge cases

    func testLoaderVersion_multipleLoaders() throws {
        let json = """
        {
            "id": "1.0",
            "stable": true,
            "loaders": [
                {"id": "fabric", "url": "https://a.com", "stable": true},
                {"id": "quilt", "url": "https://b.com", "stable": false}
            ]
        }
        """
        let version = try JSONDecoder().decode(LoaderVersion.self, from: Data(json.utf8))

        XCTAssertEqual(version.loaders.count, 2)
        XCTAssertTrue(version.loaders[0].stable)
        XCTAssertFalse(version.loaders[1].stable)
    }

    // MARK: - Processor edge cases

    func testProcessor_allFields() throws {
        let json = """
        {
            "sides": ["client", "server"],
            "jar": "processor.jar",
            "classpath": ["lib1.jar", "lib2.jar"],
            "args": ["--input", "{INPUT}", "--output", "{OUTPUT}"],
            "outputs": {"output1.jar": "sha1:abc", "output2.jar": "sha1:def"}
        }
        """
        let processor = try JSONDecoder().decode(Processor.self, from: Data(json.utf8))

        XCTAssertEqual(processor.sides?.count, 2)
        XCTAssertEqual(processor.classpath?.count, 2)
        XCTAssertEqual(processor.args?.count, 4)
        XCTAssertEqual(processor.outputs?.count, 2)
    }

    func testProcessor_sidesOnlyClient() throws {
        let json = """
        {"sides": ["client"], "jar": "p.jar"}
        """
        let processor = try JSONDecoder().decode(Processor.self, from: Data(json.utf8))

        XCTAssertEqual(processor.sides, ["client"])
        XCTAssertNil(processor.classpath)
    }

    // MARK: - SidedDataEntry edge cases

    func testSidedDataEntry_differentValues() throws {
        let entry = SidedDataEntry(client: "client-data", server: "server-data")
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(SidedDataEntry.self, from: data)

        XCTAssertEqual(decoded.client, "client-data")
        XCTAssertEqual(decoded.server, "server-data")
    }

    func testSidedDataEntry_sameValues() throws {
        let entry = SidedDataEntry(client: "shared", server: "shared")
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(SidedDataEntry.self, from: data)

        XCTAssertEqual(decoded.client, decoded.server)
    }
}
