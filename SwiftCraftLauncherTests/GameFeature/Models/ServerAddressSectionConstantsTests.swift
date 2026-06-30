//
//  ServerAddressSectionConstantsTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ServerAddressSectionConstantsTests: XCTestCase {
    func testMaxHeight() {
        XCTAssertEqual(ServerAddressSectionConstants.maxHeight, 235)
    }

    func testVerticalPadding() {
        XCTAssertEqual(ServerAddressSectionConstants.verticalPadding, 4)
    }

    func testHeaderBottomPadding() {
        XCTAssertEqual(ServerAddressSectionConstants.headerBottomPadding, 4)
    }

    func testPlaceholderCount() {
        XCTAssertEqual(ServerAddressSectionConstants.placeholderCount, 5)
    }

    func testPopoverWidth() {
        XCTAssertEqual(ServerAddressSectionConstants.popoverWidth, 320)
    }

    func testPopoverMaxHeight() {
        XCTAssertEqual(ServerAddressSectionConstants.popoverMaxHeight, 320)
    }

    func testChipPadding() {
        XCTAssertEqual(ServerAddressSectionConstants.chipPadding, 16)
    }

    func testEstimatedCharWidth() {
        XCTAssertEqual(ServerAddressSectionConstants.estimatedCharWidth, 10)
    }

    func testMaxItems() {
        XCTAssertEqual(ServerAddressSectionConstants.maxItems, 4)
    }

    func testMaxWidth() {
        XCTAssertEqual(ServerAddressSectionConstants.maxWidth, 320)
    }
}
