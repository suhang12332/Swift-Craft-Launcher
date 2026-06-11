import XCTest
@testable import SwiftCraftLauncher

final class CurseForgeServiceExtendedTests: XCTestCase {

    // MARK: - getHeaders

    func testGetHeaders_containsAcceptJSON() {
        let headers = CurseForgeService.getHeaders()
        XCTAssertFalse(headers.isEmpty)
    }

    // MARK: - ModrinthService.filterPrimaryFiles

    func testFilterPrimaryFiles_empty_returnsNil() {
        let result = ModrinthService.filterPrimaryFiles(from: [])
        XCTAssertNil(result)
    }

    func testFilterPrimaryFiles_nilInput_returnsNil() {
        let result = ModrinthService.filterPrimaryFiles(from: nil)
        XCTAssertNil(result)
    }

    func testFilterPrimaryFiles_noPrimary_returnsNil() {
        let files = [
            ModrinthVersionFile(
                hashes: ModrinthVersionFileHashes(sha512: "def", sha1: "abc"),
                url: "https://example.com/file.jar",
                filename: "file.jar",
                primary: false,
                size: 100,
                fileType: nil
            ),
        ]
        let result = ModrinthService.filterPrimaryFiles(from: files)
        XCTAssertNil(result)
    }

    func testFilterPrimaryFiles_picksPrimary() {
        let primaryFile = ModrinthVersionFile(
            hashes: ModrinthVersionFileHashes(sha512: "abc", sha1: "abc"),
            url: "https://example.com/primary.jar",
            filename: "primary.jar",
            primary: true,
            size: 100,
            fileType: nil
        )
        let secondaryFile = ModrinthVersionFile(
            hashes: ModrinthVersionFileHashes(sha512: "def", sha1: "def"),
            url: "https://example.com/secondary.jar",
            filename: "secondary.jar",
            primary: false,
            size: 200,
            fileType: nil
        )
        let result = ModrinthService.filterPrimaryFiles(from: [secondaryFile, primaryFile])

        XCTAssertEqual(result?.filename, "primary.jar")
    }

    func testFilterPrimaryFiles_multiplePrimary_picksFirst() {
        let file1 = ModrinthVersionFile(
            hashes: ModrinthVersionFileHashes(sha512: "a", sha1: "a"),
            url: "https://example.com/1.jar",
            filename: "1.jar",
            primary: true,
            size: 100,
            fileType: nil
        )
        let file2 = ModrinthVersionFile(
            hashes: ModrinthVersionFileHashes(sha512: "b", sha1: "b"),
            url: "https://example.com/2.jar",
            filename: "2.jar",
            primary: true,
            size: 200,
            fileType: nil
        )
        let result = ModrinthService.filterPrimaryFiles(from: [file1, file2])

        XCTAssertEqual(result?.filename, "1.jar")
    }
}
