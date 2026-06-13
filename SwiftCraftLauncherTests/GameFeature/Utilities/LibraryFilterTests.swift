import XCTest
@testable import SwiftCraftLauncher

final class LibraryFilterTests: XCTestCase {

    private func makeLibrary(
        rules: [Rule]? = nil,
        downloadable: Bool = true,
        includeInClasspath: Bool = true
    ) throws -> Library {
        let json: [String: Any] = [
            "downloads": [
                "artifact": [
                    "path": "org/example/lib-1.0.jar",
                    "sha1": "abc",
                    "size": 100,
                    "url": "https://example.com/lib.jar",
                ],
            ],
            "name": "test:lib:1.0",
            "include_in_classpath": includeInClasspath,
            "downloadable": downloadable,
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(Library.self, from: jsonData)
    }

    func testIsLibraryAllowed_noRules_returnsTrue() throws {
        let library = try makeLibrary(rules: nil)
        XCTAssertTrue(LibraryFilter.isLibraryAllowed(library))
    }

    func testIsLibraryAllowed_emptyRules_returnsTrue() throws {
        let library = try makeLibrary(rules: [])
        XCTAssertTrue(LibraryFilter.isLibraryAllowed(library))
    }

    func testIsLibraryAllowed_allowAll() throws {
        let library = try makeLibrary(rules: [
            Rule(action: "allow", features: nil, os: nil)
        ])
        XCTAssertTrue(LibraryFilter.isLibraryAllowed(library))
    }

    func testShouldDownloadLibrary_downloadableTrue() throws {
        let library = try makeLibrary(downloadable: true)
        XCTAssertTrue(LibraryFilter.shouldDownloadLibrary(library))
    }

    func testShouldDownloadLibrary_downloadableFalse() throws {
        let library = try makeLibrary(downloadable: false)
        XCTAssertFalse(LibraryFilter.shouldDownloadLibrary(library))
    }

    func testShouldIncludeInClasspath_bothTrue() throws {
        let library = try makeLibrary(downloadable: true, includeInClasspath: true)
        XCTAssertTrue(LibraryFilter.shouldIncludeInClasspath(library))
    }

    func testShouldIncludeInClasspath_notDownloadable() throws {
        let library = try makeLibrary(downloadable: false, includeInClasspath: true)
        XCTAssertFalse(LibraryFilter.shouldIncludeInClasspath(library))
    }

    func testShouldIncludeInClasspath_notInClasspath() throws {
        let library = try makeLibrary(downloadable: true, includeInClasspath: false)
        XCTAssertFalse(LibraryFilter.shouldIncludeInClasspath(library))
    }
}
