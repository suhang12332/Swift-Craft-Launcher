//
//  CustomYggdrasilServerStoreTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class CustomYggdrasilServerStoreTests: XCTestCase {
    private var suiteName = ""
    private var defaults = UserDefaults.standard
    private var store = CustomYggdrasilServerStore()

    override func setUpWithError() throws {
        // 每个用例使用独立的隔离套件,避免污染真实 UserDefaults
        suiteName = "CustomYggdrasilServerStoreTests_\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
        store = CustomYggdrasilServerStore(defaults: defaults)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testAdd_addsServerAndPersists() throws {
        let server = try store.add(name: "Test", apiRoot: "https://example.com/api/yggdrasil/", nonEmailLogin: true)

        XCTAssertEqual(store.servers.count, 1)
        XCTAssertEqual(server.apiRoot, "https://example.com/api/yggdrasil", "尾斜杠应被规范化")
        XCTAssertTrue(server.nonEmailLogin)

        // 持久化:新实例能读回
        let reloaded = CustomYggdrasilServerStore(defaults: defaults)
        XCTAssertEqual(reloaded.servers, store.servers)
    }

    func testAdd_rejectsDuplicatedAPIRoot() throws {
        _ = try store.add(name: "A", apiRoot: "https://example.com/api/yggdrasil", nonEmailLogin: false)

        XCTAssertThrowsError(
            try store.add(name: "B", apiRoot: "https://example.com/api/yggdrasil", nonEmailLogin: false)
        ) { error in
            let globalError = GlobalError.from(error)
            XCTAssertEqual(globalError.i18nKey, "yggdrasil.custom.error.duplicated")
        }
    }

    func testAdd_rejectsWhenLimitReached() throws {
        for index in 0 ..< CustomYggdrasilServerStore.maxServers {
            _ = try store.add(name: "S\(index)", apiRoot: "https://s\(index).example.com/api/yggdrasil", nonEmailLogin: false)
        }

        XCTAssertThrowsError(
            try store.add(name: "Extra", apiRoot: "https://extra.example.com/api/yggdrasil", nonEmailLogin: false)
        ) { error in
            let globalError = GlobalError.from(error)
            XCTAssertEqual(globalError.i18nKey, "yggdrasil.custom.error.limit_reached")
        }
    }

    func testRemove_removesServer() throws {
        let server = try store.add(name: "Test", apiRoot: "https://example.com/api/yggdrasil", nonEmailLogin: false)

        try store.remove(id: server.id, referencedBaseURLs: [])

        XCTAssertTrue(store.servers.isEmpty)
    }

    func testRemove_rejectsReferencedServer() throws {
        let server = try store.add(name: "Test", apiRoot: "https://example.com/api/yggdrasil", nonEmailLogin: false)

        XCTAssertThrowsError(
            try store.remove(
                id: server.id,
                referencedBaseURLs: [CustomYggdrasilServerStore.configBaseURL(for: server)],
            )
        ) { error in
            let globalError = GlobalError.from(error)
            XCTAssertEqual(globalError.i18nKey, "yggdrasil.custom.error.in_use")
        }
        XCTAssertEqual(store.servers.count, 1, "被引用的服务器不应被删除")
    }

    func testToConfig_passwordLoginShape() {
        let server = CustomYggdrasilServer(
            id: "id-1",
            serverName: "Test",
            apiRoot: "https://example.com/api/yggdrasil",
            nonEmailLogin: false,
            dateAdded: Date(),
        )

        let config = CustomYggdrasilServerStore.toConfig(server)

        XCTAssertEqual(config.name, "Test")
        XCTAssertEqual(config.loginMethod, .password)
        XCTAssertEqual(config.parserId, .custom)
        XCTAssertEqual(config.apiRoot?.absoluteString, "https://example.com/api/yggdrasil")
        XCTAssertEqual(config.passwordAPIRoot?.absoluteString, "https://example.com/api/yggdrasil")
        XCTAssertTrue(config.isPasswordLogin)
    }

    func testNormalizeAPIRoot_trimsTrailingSlashesAndWhitespace() {
        XCTAssertEqual(
            CustomYggdrasilServerStore.normalizeAPIRoot("  https://example.com/api/yggdrasil//  "),
            "https://example.com/api/yggdrasil",
        )
    }
}
