import CFModrinthAdapterKit
import XCTest
@testable import SwiftCraftLauncher

final class ModrinthServiceTests: XCTestCase {
    private func makeFile(filename: String, primary: Bool) -> ModrinthVersionFile {
        ModrinthVersionFile(
            hashes: ModrinthVersionFileHashes(sha512: "", sha1: "abc"),
            url: "https://example.com/\(filename)",
            filename: filename,
            primary: primary,
            size: 1024,
            fileType: nil
        )
    }

    func testFilterPrimaryFiles_picksPrimary() {
        let files = [
            makeFile(filename: "secondary.jar", primary: false),
            makeFile(filename: "primary.jar", primary: true),
        ]

        let result = ModrinthService.filterPrimaryFiles(from: files)

        XCTAssertEqual(result?.filename, "primary.jar")
        XCTAssertTrue(result?.primary == true)
    }

    func testFilterPrimaryFiles_noPrimary_returnsNil() {
        let files = [
            makeFile(filename: "a.jar", primary: false),
            makeFile(filename: "b.jar", primary: false),
        ]

        XCTAssertNil(ModrinthService.filterPrimaryFiles(from: files))
    }

    func testFilterPrimaryFiles_nilInput_returnsNil() {
        XCTAssertNil(ModrinthService.filterPrimaryFiles(from: nil))
    }

    func testFilterPrimaryFiles_empty_returnsNil() {
        XCTAssertNil(ModrinthService.filterPrimaryFiles(from: []))
    }
}
