//
//  DownloadSourceResolverTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class DownloadSourceResolverTests: XCTestCase {
    private let assetsURL = URL(string: "https://resources.download.minecraft.net/b6/b62ca8ec")!
    private let clientURL = URL(string: "https://piston-data.mojang.com/v1/objects/abc/client.jar")!
    private let libraryURL = URL(string: "https://libraries.minecraft.net/com/mojang/gson/2.10/gson-2.10.jar")!
    private let unrelatedURL = URL(string: "https://cdn.azul.com/zulu/bin/zulu17.zip")!

    func testMirror_rewritesAssetHostWithPathPrefix() {
        let mirrored = DownloadMirror.bmclapi.mirroredURL(for: assetsURL)
        XCTAssertEqual(mirrored?.absoluteString, "https://bmclapi2.bangbang93.com/assets/b6/b62ca8ec")
    }

    func testMirror_preservesOfficialPathForPistonHosts() {
        let mirrored = DownloadMirror.bmclapi.mirroredURL(for: clientURL)
        XCTAssertEqual(mirrored?.absoluteString, "https://bmclapi2.bangbang93.com/v1/objects/abc/client.jar")
    }

    func testMirror_rewritesLibraryHost() {
        let mirrored = DownloadMirror.bmclapi.mirroredURL(for: libraryURL)
        XCTAssertEqual(mirrored?.absoluteString, "https://bmclapi2.bangbang93.com/libraries/com/mojang/gson/2.10/gson-2.10.jar")
    }

    func testMirror_returnsNilForUncoveredHost() {
        XCTAssertNil(DownloadMirror.bmclapi.mirroredURL(for: unrelatedURL))
        XCTAssertFalse(DownloadMirror.bmclapi.covers(unrelatedURL))
    }

    func testCandidates_automaticPrefersMirror() async {
        await DownloadSourceResolver.shared.resetHealth()
        let urls = await DownloadSourceResolver.shared.candidateURLs(for: assetsURL, preference: .automatic)
        XCTAssertEqual(urls.count, 2)
        XCTAssertEqual(urls.first?.host, "bmclapi2.bangbang93.com")
        XCTAssertEqual(urls.last?.host, "resources.download.minecraft.net")
    }

    func testCandidates_officialPrefersOfficialHost() async {
        await DownloadSourceResolver.shared.resetHealth()
        let urls = await DownloadSourceResolver.shared.candidateURLs(for: assetsURL, preference: .official)
        XCTAssertEqual(urls.count, 2)
        XCTAssertEqual(urls.first?.host, "resources.download.minecraft.net")
        XCTAssertEqual(urls.last?.host, "bmclapi2.bangbang93.com")
    }

    func testCandidates_officialOnlyDropsMirror() async {
        await DownloadSourceResolver.shared.resetHealth()
        let urls = await DownloadSourceResolver.shared.candidateURLs(for: assetsURL, preference: .officialOnly)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first?.absoluteString, assetsURL.absoluteString)
    }

    func testCandidates_uncoveredHostYieldsSingleSource() async {
        await DownloadSourceResolver.shared.resetHealth()
        let urls = await DownloadSourceResolver.shared.candidateURLs(for: unrelatedURL, preference: .automatic)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first?.absoluteString, unrelatedURL.absoluteString)
    }

    func testHealth_demotesMirrorAfterRepeatedHostFailures() async {
        await DownloadSourceResolver.shared.resetHealth()
        let mirrorHost = "bmclapi2.bangbang93.com"
        for _ in 0 ..< 3 {
            await DownloadSourceResolver.shared.recordFailure(host: mirrorHost, failure: .host)
        }

        let urls = await DownloadSourceResolver.shared.candidateURLs(for: assetsURL, preference: .automatic)
        XCTAssertEqual(urls.first?.host, "resources.download.minecraft.net")
    }

    func testHealth_contentFailuresDoNotDemote() async {
        await DownloadSourceResolver.shared.resetHealth()
        let mirrorHost = "bmclapi2.bangbang93.com"
        for _ in 0 ..< 3 {
            await DownloadSourceResolver.shared.recordFailure(host: mirrorHost, failure: .content)
        }

        let urls = await DownloadSourceResolver.shared.candidateURLs(for: assetsURL, preference: .automatic)
        XCTAssertEqual(urls.first?.host, mirrorHost)
    }

    func testHealth_successClearsFailureStreak() async {
        await DownloadSourceResolver.shared.resetHealth()
        let mirrorHost = "bmclapi2.bangbang93.com"
        await DownloadSourceResolver.shared.recordFailure(host: mirrorHost, failure: .host)
        await DownloadSourceResolver.shared.recordFailure(host: mirrorHost, failure: .host)
        await DownloadSourceResolver.shared.recordSuccess(host: mirrorHost)
        await DownloadSourceResolver.shared.recordFailure(host: mirrorHost, failure: .host)

        let urls = await DownloadSourceResolver.shared.candidateURLs(for: assetsURL, preference: .automatic)
        XCTAssertEqual(urls.first?.host, mirrorHost)
    }

    func testFailureClassify_rateLimitedIsContentFailure() {
        let error = DownloadHTTPStatusError.httpStatus(429)
        XCTAssertEqual(DownloadSourceFailure.classify(error), .content)
    }

    func testFailureClassify_serverErrorIsHostFailure() {
        let error = DownloadHTTPStatusError.httpStatus(503)
        XCTAssertEqual(DownloadSourceFailure.classify(error), .host)
    }

    func testFailureClassify_networkUnreachableIsHostFailure() {
        let error = URLError(.cannotConnectToHost)
        XCTAssertEqual(DownloadSourceFailure.classify(error), .host)
    }

    /// `GlobalError.download` used to have no `statusCode` parameter, so an HTTP
    /// error from the chunked path arrived here with no code and fell through to
    /// `.host`. A host that answered 403 was demoted for five minutes.
    func testFailureClassify_forbiddenFromChunkedDownloadIsContentFailure() {
        let error = GlobalError.download(
            i18nKey: "error.download.http_status_error",
            statusCode: 403,
        )
        XCTAssertEqual(DownloadSourceFailure.classify(error), .content)
    }

    func testFailureClassify_notFoundFromChunkedDownloadIsContentFailure() {
        let error = GlobalError.download(
            i18nKey: "error.download.http_status_error",
            statusCode: 404,
        )
        XCTAssertEqual(DownloadSourceFailure.classify(error), .content)
    }

    func testFailureClassify_serverErrorFromChunkedDownloadIsHostFailure() {
        let error = GlobalError.download(
            i18nKey: "error.download.http_status_error",
            statusCode: 500,
        )
        XCTAssertEqual(DownloadSourceFailure.classify(error), .host)
    }
}
