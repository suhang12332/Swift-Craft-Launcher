//
//  InstallationTaskManagerTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

@MainActor
final class InstallationTaskManagerTests: XCTestCase {
    func testTaskCompletesAfterPresentingViewIsGone() async throws {
        var didComplete = false

        _ = InstallationTaskManager.shared.start {
            try? await Task.sleep(nanoseconds: 20_000_000)
            didComplete = true
        }

        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(didComplete)
    }

    func testCancelStopsRetainedTask() async throws {
        var didCancel = false

        let taskID = InstallationTaskManager.shared.start {
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch is CancellationError {
                didCancel = true
            } catch {
                XCTFail("Unexpected task error: \(error)")
            }
        }

        try await Task.sleep(nanoseconds: 20_000_000)
        InstallationTaskManager.shared.cancel(taskID)
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertTrue(didCancel)
    }
}
