//
//  CurseForgeServiceTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class CurseForgeServiceTests: XCTestCase {
    func testParseCurseForgeId_withPrefix() throws {
        let result = try CurseForgeService.parseCurseForgeId("cf-238222")
        XCTAssertEqual(result.modId, 238_222)
        XCTAssertEqual(result.normalized, "cf-238222")
    }

    func testParseCurseForgeId_plainNumber_addsPrefix() throws {
        let result = try CurseForgeService.parseCurseForgeId("238222")
        XCTAssertEqual(result.modId, 238_222)
        XCTAssertEqual(result.normalized, "cf-238222")
    }

    func testParseCurseForgeId_invalid_throws() {
        XCTAssertThrowsError(try CurseForgeService.parseCurseForgeId("cf-abc")) { error in
            let globalError = error as? GlobalError
            XCTAssertEqual(globalError?.i18nKey, "error.validation.invalid_project_id")
        }
    }

    func testFilterPrimaryFiles_nil_returnsNil() {
        XCTAssertNil(CurseForgeService.filterPrimaryFiles(from: nil))
    }

    func testFilterPrimaryFiles_empty_returnsNil() {
        XCTAssertNil(CurseForgeService.filterPrimaryFiles(from: []))
    }
}
