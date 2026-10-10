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
        // Each test uses an isolated suite so the real UserDefaults stay untouched.
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
        XCTAssertEqual(server.apiRoot, "https://example.com/api/yggdrasil", "Trailing slashes should be normalized")
        XCTAssertTrue(server.nonEmailLogin)

        // Persistence: a fresh instance reads the servers back.
        let reloaded = CustomYggdrasilServerStore(defaults: defaults)
        XCTAssertEqual(reloaded.servers, store.servers)
    }

    func testAdd_rejectsDuplicatedAPIRoot() throws {
        _ = try store.add(name: "A", apiRoot: "https://example.com/api/yggdrasil", nonEmailLogin: false)

        XCTAssertThrowsError(
            try store.add(name: "B", apiRoot: "https://example.com/api/yggdrasil", nonEmailLogin: false),
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
            try store.add(name: "Extra", apiRoot: "https://extra.example.com/api/yggdrasil", nonEmailLogin: false),
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
            ),
        ) { error in
            let globalError = GlobalError.from(error)
            XCTAssertEqual(globalError.i18nKey, "yggdrasil.custom.error.in_use")
        }
        XCTAssertEqual(store.servers.count, 1, "A referenced server must not be removed")
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

    func testAdd_rejectsPlainHTTP() {
        for apiRoot in ["http://example.com/api/yggdrasil", "http://192.168.1.10/api/yggdrasil", "HTTP://skin.local"] {
            XCTAssertThrowsError(try store.add(name: "Insecure", apiRoot: apiRoot, nonEmailLogin: false), apiRoot) { error in
                XCTAssertEqual(GlobalError.from(error).i18nKey, "yggdrasil.custom.error.https_required")
            }
        }
        XCTAssertTrue(store.servers.isEmpty, "Servers that would receive passwords over HTTP must not be saved")
    }

    func testValidatedAPIRoot_rejectsMalformedAndAcceptsHTTPS() throws {
        for raw in ["", "example.com/api/yggdrasil", "https://"] {
            XCTAssertThrowsError(try CustomYggdrasilServerStore.validatedAPIRoot(raw), raw) { error in
                XCTAssertEqual(GlobalError.from(error).i18nKey, "yggdrasil.custom.error.invalid_url")
            }
        }
        let url = try CustomYggdrasilServerStore.validatedAPIRoot(" https://example.com/api/yggdrasil/ ")
        XCTAssertEqual(url.absoluteString, "https://example.com/api/yggdrasil")
    }

    func testNormalizeAPIRoot_trimsTrailingSlashesAndWhitespace() {
        XCTAssertEqual(
            CustomYggdrasilServerStore.normalizeAPIRoot("  https://example.com/api/yggdrasil//  "),
            "https://example.com/api/yggdrasil",
        )
    }
}
