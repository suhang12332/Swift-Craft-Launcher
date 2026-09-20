//
//  UpdateSourceSelectorTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
@testable import SwiftCraftLauncher
import XCTest

final class UpdateSourceSelectorTests: XCTestCase {
    private let fallback = UpdateSource(
        id: "fallback",
        name: "Fallback",
        appcastBaseURL: URL(string: "https://fallback.example")!,
        downloadBaseURL: URL(string: "https://fallback-download.example")!,
    )
    private let mirror = UpdateSource(
        id: "mirror",
        name: "Mirror",
        appcastBaseURL: URL(string: "https://mirror.example")!,
        downloadBaseURL: URL(string: "https://mirror.example")!,
    )

    func testSelectsFastestHealthySource() async {
        let selector = makeSelector { source, _ in source.id == "mirror" ? 0.05 : 0.20 }

        let selected = await selector.selectSource(architecture: "arm64")

        XCTAssertEqual(selected, mirror)
    }

    func testIgnoresFastUnhealthySource() async {
        let selector = makeSelector { source, _ in source.id == "mirror" ? nil : 0.20 }

        let selected = await selector.selectSource(architecture: "arm64")

        XCTAssertEqual(selected, fallback)
    }

    func testFallsBackWhenEverySourceFails() async {
        let recorder = ProbeRecorder(results: [:])
        let selector = makeSelector { source, _ in await recorder.result(for: source.id) }

        let firstSelection = await selector.selectSource(architecture: "x86_64")
        let secondSelection = await selector.selectSource(architecture: "x86_64")

        XCTAssertEqual(firstSelection, fallback)
        XCTAssertEqual(secondSelection, fallback)
        let probeCount = await recorder.callCount
        XCTAssertEqual(probeCount, 4)
    }

    func testCachesSelectionForSameArchitecture() async {
        let recorder = ProbeRecorder(results: ["fallback": 0.2, "mirror": 0.1])
        let selector = makeSelector { source, _ in await recorder.result(for: source.id) }

        _ = await selector.selectSource(architecture: "arm64")
        _ = await selector.selectSource(architecture: "arm64")

        let probeCount = await recorder.callCount
        XCTAssertEqual(probeCount, 2)
    }

    func testForceRefreshBypassesCache() async {
        let recorder = ProbeRecorder(results: ["fallback": 0.2, "mirror": 0.1])
        let selector = makeSelector { source, _ in await recorder.result(for: source.id) }

        _ = await selector.selectSource(architecture: "arm64")
        _ = await selector.selectSource(architecture: "arm64", forceRefresh: true)

        let probeCount = await recorder.callCount
        XCTAssertEqual(probeCount, 4)
    }

    func testUpdateSourceBuildsArchitectureAndDownloadURLs() {
        XCTAssertEqual(
            mirror.appcastURL(architecture: "x86_64").absoluteString,
            "https://mirror.example/appcast-x86_64.xml",
        )
        XCTAssertEqual(
            mirror.downloadURL(version: "1.3.3", fileName: "Swift-Craft-Launcher-arm64-1.3.3.dmg").absoluteString,
            "https://mirror.example/1.3.3/Swift-Craft-Launcher-arm64-1.3.3.dmg",
        )
    }

    func testValidatesArchitectureSpecificSignedAppcast() {
        let validAppcast = Data(
            """
            <rss xmlns:sparkle="https://sparkle-project.org/xml-namespaces/sparkle">
              <sparkle:shortVersionString>1.3.3</sparkle:shortVersionString>
              <enclosure url="Swift-Craft-Launcher-arm64-1.3.3.dmg" sparkle:edSignature="signature" />
            </rss>
            """.utf8,
        )

        XCTAssertTrue(UpdateSourceSelector.isValidAppcast(validAppcast, architecture: "arm64"))
        XCTAssertFalse(UpdateSourceSelector.isValidAppcast(validAppcast, architecture: "x86_64"))
        XCTAssertFalse(UpdateSourceSelector.isValidAppcast(Data("not xml".utf8), architecture: "arm64"))
    }

    private func makeSelector(probe: @escaping UpdateSourceSelector.Probe) -> UpdateSourceSelector {
        UpdateSourceSelector(
            sources: [fallback, mirror],
            fallbackSource: fallback,
            probe: probe,
        )
    }
}

private actor ProbeRecorder {
    private(set) var callCount = 0
    private let results: [String: TimeInterval]

    init(results: [String: TimeInterval]) {
        self.results = results
    }

    func result(for sourceID: String) -> TimeInterval? {
        callCount += 1
        return results[sourceID]
    }
}
