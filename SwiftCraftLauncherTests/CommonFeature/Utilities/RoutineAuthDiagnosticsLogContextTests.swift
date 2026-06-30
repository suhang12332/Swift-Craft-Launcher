//
//  RoutineAuthDiagnosticsLogContextTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class RoutineAuthDiagnosticsLogContextTests: XCTestCase {

    func testShouldSuppressRoutineDebugLogs_defaultIsFalse() {
        XCTAssertFalse(RoutineAuthDiagnosticsLogContext.shouldSuppressRoutineDebugLogs)
    }

    func testWithSuppressedRoutineDebugLogs_setsTrueInside() async {
        await RoutineAuthDiagnosticsLogContext.withSuppressedRoutineDebugLogs {
            XCTAssertTrue(RoutineAuthDiagnosticsLogContext.shouldSuppressRoutineDebugLogs)
        }
    }

    func testWithSuppressedRoutineDebugLogs_restoresAfter() async {
        XCTAssertFalse(RoutineAuthDiagnosticsLogContext.shouldSuppressRoutineDebugLogs)

        await RoutineAuthDiagnosticsLogContext.withSuppressedRoutineDebugLogs {
            XCTAssertTrue(RoutineAuthDiagnosticsLogContext.shouldSuppressRoutineDebugLogs)
        }

        XCTAssertFalse(RoutineAuthDiagnosticsLogContext.shouldSuppressRoutineDebugLogs)
    }

    func testWithSuppressedRoutineDebugLogs_nestedOuterStillFalse() async {
        XCTAssertFalse(RoutineAuthDiagnosticsLogContext.shouldSuppressRoutineDebugLogs)

        await RoutineAuthDiagnosticsLogContext.withSuppressedRoutineDebugLogs {
            XCTAssertTrue(RoutineAuthDiagnosticsLogContext.shouldSuppressRoutineDebugLogs)
        }

        XCTAssertFalse(RoutineAuthDiagnosticsLogContext.shouldSuppressRoutineDebugLogs)
    }
}
