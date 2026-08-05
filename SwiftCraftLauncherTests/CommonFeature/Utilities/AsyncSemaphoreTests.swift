//
//  AsyncSemaphoreTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class AsyncSemaphoreTests: XCTestCase {
    func testWait_withAvailableSlots() async {
        let semaphore = AsyncSemaphore(value: 2)
        await semaphore.wait()
        await semaphore.signal()
    }

    func testSignal_restoresSlot() async {
        let semaphore = AsyncSemaphore(value: 1)
        await semaphore.wait()
        await semaphore.signal()
        await semaphore.wait()
        await semaphore.signal()
    }

    func testConcurrentAccess() async {
        let semaphore = AsyncSemaphore(value: 2)

        let total = await withTaskGroup(of: Int.self) { group in
            for _ in 0 ..< 5 {
                group.addTask {
                    await semaphore.wait()
                    await semaphore.signal()
                    return 1
                }
            }
            var sum = 0
            for await value in group {
                sum += value
            }
            return sum
        }

        XCTAssertEqual(total, 5)
    }
}
