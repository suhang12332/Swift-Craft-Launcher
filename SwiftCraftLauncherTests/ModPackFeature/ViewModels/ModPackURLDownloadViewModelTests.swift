//
//  ModPackURLDownloadViewModelTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

@MainActor
final class ModPackURLDownloadViewModelTests: XCTestCase {
    private func makeViewModel() -> ModPackURLDownloadViewModel {
        ModPackURLDownloadViewModel()
    }

    func testIsURLValid_validHTTPURL_returnsTrue() {
        let vm = makeViewModel()
        vm.urlString = "http://example.com/modpack.zip"
        XCTAssertTrue(vm.isURLValid)
    }

    func testIsURLValid_validHTTPSURL_returnsTrue() {
        let vm = makeViewModel()
        vm.urlString = "https://example.com/modpack.zip"
        XCTAssertTrue(vm.isURLValid)
    }

    func testIsURLValid_emptyString_returnsFalse() {
        let vm = makeViewModel()
        vm.urlString = ""
        XCTAssertFalse(vm.isURLValid)
    }

    func testIsURLValid_invalidScheme_returnsFalse() {
        let vm = makeViewModel()
        vm.urlString = "ftp://example.com/modpack.zip"
        XCTAssertFalse(vm.isURLValid)
    }

    func testIsURLValid_invalidURL_returnsFalse() {
        let vm = makeViewModel()
        vm.urlString = "not a url"
        XCTAssertFalse(vm.isURLValid)
    }

    func testIsURLValid_ftpWithPort_returnsFalse() {
        let vm = makeViewModel()
        vm.urlString = "ftp://example.com:8080/modpack.zip"
        XCTAssertFalse(vm.isURLValid)
    }

    func testInitialState_stringIsEmpty() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.urlString, "")
    }

    func testInitialState_isDownloadingFalse() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.isDownloading)
    }

    func testInitialState_downloadProgressZero() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.downloadProgress, 0)
    }

    func testInitialState_downloadTotalSizeZero() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.downloadTotalSize, 0)
    }

    func testInitialState_errorMessageNil() {
        let vm = makeViewModel()
        XCTAssertNil(vm.errorMessage)
    }

    func testCancel_setsIsDownloadingFalse() {
        let vm = makeViewModel()
        vm.isDownloading = true
        vm.cancel()
        XCTAssertFalse(vm.isDownloading)
    }

    func testCancel_clearsDownloadTask() {
        let vm = makeViewModel()
        vm.cancel()
        XCTAssertFalse(vm.isDownloading)
    }

    func testStartDownload_invalidURL_setsErrorAndCallsOnFailure() {
        let vm = makeViewModel()
        vm.urlString = ""

        let expectation = expectation(description: "onFailure called")
        vm.startDownload(onComplete: { _ in
            XCTFail("onComplete should not be called")
        }, onFailure: {
            expectation.fulfill()
        })

        waitForExpectations(timeout: 1)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isDownloading)
    }

    func testStartDownload_invalidURL_errorMessageIsNotNil() {
        let vm = makeViewModel()
        vm.urlString = ""

        vm.startDownload(onComplete: { _ in }, onFailure: { })

        XCTAssertNotNil(vm.errorMessage)
    }

    func testStartDownload_validURL_setsDownloadingTrue() {
        let vm = makeViewModel()
        vm.urlString = "https://example.com/modpack.zip"

        vm.startDownload(onComplete: { _ in }, onFailure: { })

        XCTAssertTrue(vm.isDownloading)
    }

    func testStartDownload_validURL_clearsErrorMessage() {
        let vm = makeViewModel()
        vm.errorMessage = "previous error"
        vm.urlString = "https://example.com/modpack.zip"

        vm.startDownload(onComplete: { _ in }, onFailure: { })

        XCTAssertNil(vm.errorMessage)
    }

    func testStartDownload_validURL_resetsProgress() {
        let vm = makeViewModel()
        vm.downloadProgress = 1000
        vm.downloadTotalSize = 5000
        vm.urlString = "https://example.com/modpack.zip"

        vm.startDownload(onComplete: { _ in }, onFailure: { })

        XCTAssertEqual(vm.downloadProgress, 0)
        XCTAssertEqual(vm.downloadTotalSize, 0)
    }

    func testStartDownload_cancelsPreviousTask() {
        let vm = makeViewModel()
        vm.urlString = "https://example.com/modpack.zip"

        vm.startDownload(onComplete: { _ in }, onFailure: { })
        vm.startDownload(onComplete: { _ in }, onFailure: { })

        XCTAssertTrue(vm.isDownloading)
    }
}
