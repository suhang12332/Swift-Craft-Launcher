import XCTest
@testable import SwiftCraftLauncher

final class ModPackFeatureExtendedTests: XCTestCase {

    // MARK: - ModrinthIndexModels

    func testModrinthIndexFileHashes_fromDict() {
        let dict = ["sha1": "abc123", "sha512": "def456"]
        let hashes = ModrinthIndexFileHashes(from: dict)
        XCTAssertEqual(hashes.sha1, "abc123")
        XCTAssertEqual(hashes.sha512, "def456")
        XCTAssertNil(hashes.other)
    }

    func testModrinthIndexFileHashes_withOtherHashes() {
        let dict = ["sha1": "abc", "md5": "xyz"]
        let hashes = ModrinthIndexFileHashes(from: dict)
        XCTAssertEqual(hashes.sha1, "abc")
        XCTAssertNotNil(hashes.other)
        XCTAssertEqual(hashes.other?["md5"], "xyz")
    }

    func testModrinthIndexFileHashes_codable() throws {
        let dict = ["sha1": "abc123", "sha512": "def456"]
        let hashes = ModrinthIndexFileHashes(from: dict)
        let data = try JSONEncoder().encode(hashes)
        let decoded = try JSONDecoder().decode(ModrinthIndexFileHashes.self, from: data)
        XCTAssertEqual(decoded.sha1, "abc123")
        XCTAssertEqual(decoded.sha512, "def456")
    }

    // MARK: - CurseForgeSlugHelper

    func testToSlug_specialCharacters() {
        let slug = CurseForgeSlugHelper.toSlug("Hello World! @#$%")
        XCTAssertFalse(slug.contains(" "))
    }

    func testIsValid_validSlug() {
        XCTAssertTrue(CurseForgeSlugHelper.isValid("my-mod-pack"))
    }

    func testIsValid_emptySlug() {
        XCTAssertFalse(CurseForgeSlugHelper.isValid(""))
    }

    func testIsValid_tooShort() {
        XCTAssertFalse(CurseForgeSlugHelper.isValid("ab"))
    }

    // MARK: - CurseForgeManifestBuilder.ManifestFile

    func testManifestFile_codable() throws {
        let file = CurseForgeManifestBuilder.ManifestFile(
            projectID: 123,
            fileID: 456,
            required: true,
            isLocked: false
        )
        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(CurseForgeManifestBuilder.ManifestFile.self, from: data)
        XCTAssertEqual(decoded.projectID, 123)
        XCTAssertEqual(decoded.fileID, 456)
        XCTAssertTrue(decoded.required)
        XCTAssertFalse(decoded.isLocked)
    }
}
