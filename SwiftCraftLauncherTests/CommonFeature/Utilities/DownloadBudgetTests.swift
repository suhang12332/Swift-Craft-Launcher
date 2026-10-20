//
//  DownloadBudgetTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class DownloadBudgetTests: XCTestCase {
    func testAcquireBeyondLimit_blocksUntilReleased() async {
        let budget = DownloadBudget(limit: 4)
        let flag = Flag()

        await budget.acquire(4)

        let pending = Task {
            await budget.acquire(1)
            await flag.set()
        }
        XCTAssertFalse(await flag.current, "a request beyond the limit must wait")

        await budget.release(4)
        await pending.value
        XCTAssertTrue(await flag.current)
    }

    func testSyncLimit_wakesWaitersWhenCapacityGrows() async {
        let budget = DownloadBudget(limit: 2)
        let flag = Flag()

        await budget.acquire(2)

        let pending = Task {
            await budget.acquire(2)
            await flag.set()
        }
        XCTAssertFalse(await flag.current)

        await budget.syncLimit(4)
        await pending.value
        XCTAssertTrue(await flag.current)
    }

    func testSyncLimit_clampsToAtLeastOne() async {
        let budget = DownloadBudget(limit: 8)
        await budget.syncLimit(0)
        let limit = await budget.currentLimit()
        XCTAssertEqual(limit, 1)
    }

    func testRelease_neverRaisesCapacityAboveLimit() async {
        let budget = DownloadBudget(limit: 2)
        let flag = Flag()

        await budget.acquire(2)
        await budget.release(10)
        await budget.acquire(2)

        let pending = Task {
            await budget.acquire(1)
            await flag.set()
        }
        XCTAssertFalse(await flag.current, "releasing more than acquired must not create capacity")

        await budget.release(2)
        await pending.value
        XCTAssertTrue(await flag.current)
    }
}

private actor Flag {
    private var value = false

    func set() {
        value = true
    }

    var current: Bool { value }
}
