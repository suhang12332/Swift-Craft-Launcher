//
//  InstallTaskCoordinatorTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

@MainActor
final class InstallTaskCoordinatorTests: XCTestCase {
    func testStart_runsOperationAndClearsRunningState() async {
        let coordinator = InstallTaskCoordinator()
        let finished = expectation(description: "onFinish called")
        var operationRan = false

        coordinator.start(
            onFinish: { finished.fulfill() },
            operation: { operationRan = true },
        )

        XCTAssertTrue(coordinator.isRunning)

        await fulfillment(of: [finished], timeout: 1)

        XCTAssertTrue(operationRan)
        XCTAssertFalse(coordinator.isRunning)
        XCTAssertFalse(coordinator.isCancelling)
    }

    func testCancel_cancelsRunningOperation() async {
        let coordinator = InstallTaskCoordinator()
        let started = expectation(description: "started")
        let cancelled = expectation(description: "cancelled")

        coordinator.start {
            started.fulfill()
            do {
                try await Task.sleep(for: .seconds(30))
            } catch {
                cancelled.fulfill()
            }
        }

        await fulfillment(of: [started], timeout: 1)
        coordinator.cancel()

        XCTAssertTrue(coordinator.isCancelling)
        XCTAssertFalse(coordinator.isRunning)

        await fulfillment(of: [cancelled], timeout: 1)
    }

    func testStart_afterCancel_resetsCancellingState() async {
        let coordinator = InstallTaskCoordinator()
        coordinator.cancel()

        XCTAssertTrue(coordinator.isCancelling)

        let finished = expectation(description: "finished")
        coordinator.start(
            onFinish: { finished.fulfill() },
            operation: { },
        )

        await fulfillment(of: [finished], timeout: 1)

        XCTAssertFalse(coordinator.isCancelling)
        XCTAssertFalse(coordinator.isRunning)
    }

    func testStart_supersedesPreviousOperation() async {
        let coordinator = InstallTaskCoordinator()
        let firstStarted = expectation(description: "first started")
        let firstCancelled = expectation(description: "first cancelled")
        let secondFinished = expectation(description: "second finished")

        coordinator.start {
            firstStarted.fulfill()
            do {
                try await Task.sleep(for: .seconds(30))
            } catch {
                firstCancelled.fulfill()
            }
        }

        await fulfillment(of: [firstStarted], timeout: 1)

        coordinator.start(
            onFinish: { secondFinished.fulfill() },
            operation: { },
        )

        await fulfillment(of: [firstCancelled, secondFinished], timeout: 1)
    }

    func testFinish_clearsStateWithoutCancelling() async {
        let coordinator = InstallTaskCoordinator()
        let started = expectation(description: "started")

        coordinator.start {
            started.fulfill()
            try? await Task.sleep(for: .milliseconds(50))
        }

        await fulfillment(of: [started], timeout: 1)
        coordinator.finish()

        XCTAssertFalse(coordinator.isRunning)
        XCTAssertFalse(coordinator.isCancelling)
    }
}
