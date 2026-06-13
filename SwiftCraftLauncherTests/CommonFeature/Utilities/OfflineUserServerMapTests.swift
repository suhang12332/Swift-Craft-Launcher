import XCTest
@testable import SwiftCraftLauncher

final class OfflineUserServerMapTests: XCTestCase {

    private let suiteName = "OfflineUserServerMapTests_\(UUID().uuidString)"
    private var defaults: UserDefaults?

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // NOTE: OfflineUserServerMap uses UserDefaults.standard internally.
    // These tests verify the public API behavior; they run against the real
    // standard UserDefaults and are isolated by unique user IDs.

    // MARK: - serverKey

    func testServerKey_noMapping_returnsNil() {
        let userId = "no-mapping-\(UUID().uuidString)"
        XCTAssertNil(OfflineUserServerMap.serverKey(for: userId))
    }

    // MARK: - setServer / serverKey round-trip

    func testSetServer_thenServerKey_returnsSameValue() {
        let userId = "round-trip-\(UUID().uuidString)"
        OfflineUserServerMap.setServer("littleskin", for: userId)

        XCTAssertEqual(OfflineUserServerMap.serverKey(for: userId), "littleskin")

        // Cleanup
        OfflineUserServerMap.removeServer(for: userId)
    }

    func testSetServer_overwritesPreviousValue() {
        let userId = "overwrite-\(UUID().uuidString)"
        OfflineUserServerMap.setServer("server-a", for: userId)
        OfflineUserServerMap.setServer("server-b", for: userId)

        XCTAssertEqual(OfflineUserServerMap.serverKey(for: userId), "server-b")

        OfflineUserServerMap.removeServer(for: userId)
    }

    // MARK: - removeServer

    func testRemoveServer_existingMapping_returnsNil() {
        let userId = "remove-\(UUID().uuidString)"
        OfflineUserServerMap.setServer("myserver", for: userId)
        OfflineUserServerMap.removeServer(for: userId)

        XCTAssertNil(OfflineUserServerMap.serverKey(for: userId))
    }

    func testRemoveServer_nonExistingMapping_noop() {
        let userId = "remove-nonexist-\(UUID().uuidString)"
        OfflineUserServerMap.removeServer(for: userId)
        XCTAssertNil(OfflineUserServerMap.serverKey(for: userId))
    }

    // MARK: - Multiple users isolation

    func testMultipleUsers_independentMappings() {
        let userA = "multi-a-\(UUID().uuidString)"
        let userB = "multi-b-\(UUID().uuidString)"

        OfflineUserServerMap.setServer("serverA", for: userA)
        OfflineUserServerMap.setServer("serverB", for: userB)

        XCTAssertEqual(OfflineUserServerMap.serverKey(for: userA), "serverA")
        XCTAssertEqual(OfflineUserServerMap.serverKey(for: userB), "serverB")

        OfflineUserServerMap.removeServer(for: userA)
        XCTAssertNil(OfflineUserServerMap.serverKey(for: userA))
        XCTAssertEqual(OfflineUserServerMap.serverKey(for: userB), "serverB")

        OfflineUserServerMap.removeServer(for: userB)
    }

    func testRemoveOneUser_doesNotAffectOther() {
        let userA = "iso-a-\(UUID().uuidString)"
        let userB = "iso-b-\(UUID().uuidString)"

        OfflineUserServerMap.setServer("s1", for: userA)
        OfflineUserServerMap.setServer("s2", for: userB)

        OfflineUserServerMap.removeServer(for: userA)

        XCTAssertNil(OfflineUserServerMap.serverKey(for: userA))
        XCTAssertEqual(OfflineUserServerMap.serverKey(for: userB), "s2")

        OfflineUserServerMap.removeServer(for: userB)
    }

    // MARK: - Server key with special characters

    func testSetServer_specialCharacters() {
        let userId = "special-\(UUID().uuidString)"
        OfflineUserServerMap.setServer("https://littleskin.cn/api", for: userId)

        XCTAssertEqual(OfflineUserServerMap.serverKey(for: userId), "https://littleskin.cn/api")

        OfflineUserServerMap.removeServer(for: userId)
    }

    func testSetServer_emptyServerKey() {
        let userId = "empty-server-\(UUID().uuidString)"
        OfflineUserServerMap.setServer("", for: userId)

        XCTAssertEqual(OfflineUserServerMap.serverKey(for: userId), "")

        OfflineUserServerMap.removeServer(for: userId)
    }

    // MARK: - Edge cases

    func testServerKey_longUserId() {
        let userId = String(repeating: "a", count: 1000)
        OfflineUserServerMap.setServer("server", for: userId)
        XCTAssertEqual(OfflineUserServerMap.serverKey(for: userId), "server")
        OfflineUserServerMap.removeServer(for: userId)
    }

    func testSetServer_emptyUserId() {
        OfflineUserServerMap.setServer("server", for: "")
        XCTAssertEqual(OfflineUserServerMap.serverKey(for: ""), "server")
        OfflineUserServerMap.removeServer(for: "")
    }
}
