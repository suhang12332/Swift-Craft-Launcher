//
//  ResourceFeatureModelsTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ResourceFeatureModelsTests: XCTestCase {
    func testLocalResourceFilter_allCases() {
        XCTAssertEqual(LocalResourceFilter.allCases.count, 2)
    }

    func testLocalResourceFilter_rawValues() {
        XCTAssertEqual(LocalResourceFilter.all.rawValue, "all")
        XCTAssertEqual(LocalResourceFilter.disabled.rawValue, "disabled")
    }

    func testLocalResourceFilter_id() {
        XCTAssertEqual(LocalResourceFilter.all.id, "all")
        XCTAssertEqual(LocalResourceFilter.disabled.id, "disabled")
    }

    func testLocalResourceFilter_icon() {
        XCTAssertEqual(LocalResourceFilter.all.icon, "list.bullet")
        XCTAssertEqual(LocalResourceFilter.disabled.icon, "nosign")
    }
}
