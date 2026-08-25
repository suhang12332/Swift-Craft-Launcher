//
//  RoutineAuthDiagnosticsLogContextTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class RoutineAuthDiagnosticsLogContextTests: XCTestCase {
    func testShouldSuppressRoutineDebugLogs_defaultIsFalse() {
        XCTAssertFalse(RoutineAuthDiagnosticsLogContext.shouldSuppressRoutineDebugLogs)
    }
}
