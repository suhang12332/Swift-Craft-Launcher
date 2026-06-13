import XCTest
@testable import SwiftCraftLauncher

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
        var counter = 0

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    await semaphore.wait()
                    counter += 1
                    await semaphore.signal()
                }
            }
        }

        XCTAssertEqual(counter, 5)
    }
}
