import XCTest
@testable import SwiftCraftLauncher

final class LibraryFilterTests: XCTestCase {

    private func makeLibrary(
        rules: [Rule]? = nil,
        downloadable: Bool = true,
        includeInClasspath: Bool = true
    ) -> Library {
        let json: [String: Any] = [
            "downloads": [
                "artifact": [
                    "path": "org/example/lib-1.0.jar",
                    "sha1": "abc",
                    "size": 100,
                    "url": "https://example.com/lib.jar"
                ]
            ],
            "name": "test:lib:1.0",
            "include_in_classpath": includeInClasspath,
            "downloadable": downloadable,
        ]

        var jsonData = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(Library.self, from: jsonData)
    }

    func testIsLibraryAllowed_noRules_returnsTrue() {
        let library = makeLibrary(rules: nil)
        XCTAssertTrue(LibraryFilter.isLibraryAllowed(library))
    }

    func testIsLibraryAllowed_emptyRules_returnsTrue() {
        let library = makeLibrary(rules: [])
        XCTAssertTrue(LibraryFilter.isLibraryAllowed(library))
    }

    func testIsLibraryAllowed_allowAll() {
        let library = makeLibrary(rules: [
            Rule(action: "allow", features: nil, os: nil)
        ])
        XCTAssertTrue(LibraryFilter.isLibraryAllowed(library))
    }

    func testShouldDownloadLibrary_downloadableTrue() {
        let library = makeLibrary(downloadable: true)
        XCTAssertTrue(LibraryFilter.shouldDownloadLibrary(library))
    }

    func testShouldDownloadLibrary_downloadableFalse() {
        let library = makeLibrary(downloadable: false)
        XCTAssertFalse(LibraryFilter.shouldDownloadLibrary(library))
    }

    func testShouldIncludeInClasspath_bothTrue() {
        let library = makeLibrary(downloadable: true, includeInClasspath: true)
        XCTAssertTrue(LibraryFilter.shouldIncludeInClasspath(library))
    }

    func testShouldIncludeInClasspath_notDownloadable() {
        let library = makeLibrary(downloadable: false, includeInClasspath: true)
        XCTAssertFalse(LibraryFilter.shouldIncludeInClasspath(library))
    }

    func testShouldIncludeInClasspath_notInClasspath() {
        let library = makeLibrary(downloadable: true, includeInClasspath: false)
        XCTAssertFalse(LibraryFilter.shouldIncludeInClasspath(library))
    }
}
