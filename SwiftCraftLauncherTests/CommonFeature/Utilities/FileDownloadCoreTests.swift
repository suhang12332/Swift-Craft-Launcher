import XCTest
@testable import SwiftCraftLauncher

final class FileDownloadCoreTests: XCTestCase {
    func testParseURL_valid() throws {
        let url = try FileDownloadCore.parseURL(from: "https://example.com/file.jar")
        XCTAssertEqual(url.absoluteString, "https://example.com/file.jar")
    }

    func testParseURL_invalid_throws() {
        XCTAssertThrowsError(try FileDownloadCore.parseURL(from: "")) { error in
            let globalError = error as? GlobalError
            XCTAssertEqual(globalError?.i18nKey, "error.validation.invalid_download_url")
        }
    }

    func testExistingFileSizeIfReusable_missingFile_returnsNil() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).jar")
        XCTAssertNil(FileDownloadCore.existingFileSizeIfReusable(at: url, expectedSha1: nil))
    }
}
