//
//  InstallationDiagnosticsLoggerTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
@testable import SwiftCraftLauncher
import XCTest

final class InstallationDiagnosticsLoggerTests: XCTestCase {
    func testInstallationTraceIsPersisted() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("InstallationDiagnosticsLoggerTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let logger = InstallationDiagnosticsLogger(directory: directory)
        let id = logger.begin(gameName: "Test Game", version: "1.21.1", modLoader: "fabric")
        logger.record(id, stage: "download.failure", message: "url=https://example.com/client.jar")
        logger.finish(id, success: false)

        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1)
        guard let logURL = files.first else { return }
        let contents = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("installation.begin"))
        XCTAssertTrue(contents.contains("download.failure"))
        XCTAssertTrue(contents.contains("https://example.com/client.jar"))
        XCTAssertTrue(contents.contains("installation.finish"))
        XCTAssertTrue(contents.contains("success=false"))
    }
}
