import XCTest
@testable import SwiftCraftLauncher

final class ModUpdateCheckerTests: XCTestCase {

    // MARK: - UpdateCheckResult

    func testUpdateCheckResult_hasUpdate() {
        let result = ModUpdateChecker.UpdateCheckResult(
            hasUpdate: true,
            currentHash: "hash-current",
            latestHash: "hash-latest",
            latestVersion: nil
        )

        XCTAssertTrue(result.hasUpdate)
        XCTAssertEqual(result.currentHash, "hash-current")
        XCTAssertEqual(result.latestHash, "hash-latest")
        XCTAssertNil(result.latestVersion)
    }

    func testUpdateCheckResult_noUpdate() {
        let result = ModUpdateChecker.UpdateCheckResult(
            hasUpdate: false,
            currentHash: "same-hash",
            latestHash: "same-hash",
            latestVersion: nil
        )

        XCTAssertFalse(result.hasUpdate)
        XCTAssertEqual(result.currentHash, result.latestHash)
    }

    func testUpdateCheckResult_nilHashes() {
        let result = ModUpdateChecker.UpdateCheckResult(
            hasUpdate: false,
            currentHash: nil,
            latestHash: nil,
            latestVersion: nil
        )

        XCTAssertFalse(result.hasUpdate)
        XCTAssertNil(result.currentHash)
        XCTAssertNil(result.latestHash)
    }

    func testUpdateCheckResult_withLatestVersion() {
        let version = ModrinthProjectDetailVersion(
            gameVersions: ["1.20.1"],
            loaders: ["fabric"],
            id: "ver-1",
            projectId: "proj-1",
            authorId: "author-1",
            featured: false,
            name: "Version 1.1",
            versionNumber: "1.1.0",
            changelog: "Bug fixes",
            changelogUrl: nil,
            datePublished: Date(timeIntervalSince1970: 1700100000),
            downloads: 50,
            versionType: "release",
            status: "listed",
            requestedStatus: nil,
            files: [],
            dependencies: []
        )

        let result = ModUpdateChecker.UpdateCheckResult(
            hasUpdate: true,
            currentHash: "old-hash",
            latestHash: "new-hash",
            latestVersion: version
        )

        XCTAssertTrue(result.hasUpdate)
        XCTAssertEqual(result.latestVersion?.name, "Version 1.1")
        XCTAssertEqual(result.latestVersion?.versionNumber, "1.1.0")
        XCTAssertEqual(result.latestVersion?.changelog, "Bug fixes")
    }
}
