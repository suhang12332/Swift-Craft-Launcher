//
//  ModPackInstallViewModelTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

@MainActor
final class ModPackInstallViewModelTests: XCTestCase {
    private func makeViewModel(source: ModPackInstallSource = .remoteURL) -> ModPackInstallViewModel {
        ModPackInstallViewModel(
            source: source,
            configuration: GameFormConfiguration(
                isDownloading: .constant(false),
                isFormValid: .constant(false),
                triggerConfirm: .constant(false),
                triggerCancel: .constant(false),
                onCancel: { },
                onConfirm: { },
            ),
        )
    }

    func testIsURLValid_validHTTPURL_returnsTrue() {
        let viewModel = makeViewModel()
        viewModel.urlString = "http://example.com/modpack.zip"
        XCTAssertTrue(viewModel.isURLValid)
    }

    func testIsURLValid_validHTTPSURL_returnsTrue() {
        let viewModel = makeViewModel()
        viewModel.urlString = "https://example.com/modpack.zip"
        XCTAssertTrue(viewModel.isURLValid)
    }

    func testIsURLValid_emptyString_returnsFalse() {
        let viewModel = makeViewModel()
        XCTAssertFalse(viewModel.isURLValid)
    }

    func testIsURLValid_invalidScheme_returnsFalse() {
        let viewModel = makeViewModel()
        viewModel.urlString = "ftp://example.com/modpack.zip"
        XCTAssertFalse(viewModel.isURLValid)
    }

    func testIsURLValid_invalidURL_returnsFalse() {
        let viewModel = makeViewModel()
        viewModel.urlString = "not a url"
        XCTAssertFalse(viewModel.isURLValid)
    }

    func testFormIsValid_onlyWhenURLIsValidBeforeDownload() {
        let viewModel = makeViewModel()
        XCTAssertFalse(viewModel.computeIsFormValid())

        viewModel.urlString = "https://example.com/modpack.zip"
        XCTAssertTrue(viewModel.computeIsFormValid())
    }

    func testFormIsInvalid_forPreparedLocalSource() {
        let viewModel = makeViewModel(source: .local(URL(fileURLWithPath: "/tmp/test.mrpack")))
        XCTAssertFalse(viewModel.computeIsFormValid())
    }

    func testProcessingSubtitle_dependsOnSource() {
        XCTAssertEqual(
            makeViewModel(source: .local(URL(fileURLWithPath: "/tmp/test.mrpack"))).processingSubtitleKey,
            "modpack.processing.subtitle.local",
        )
        XCTAssertEqual(
            makeViewModel().processingSubtitleKey,
            "modpack.processing.subtitle.remote",
        )
    }
}
