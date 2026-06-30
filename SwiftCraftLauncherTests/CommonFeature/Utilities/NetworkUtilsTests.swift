//
//  NetworkUtilsTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class NetworkUtilsTests: XCTestCase {
    func testResolveServerAddress_explicitNonDefaultPort() async {
        let resolved = await NetworkUtils.resolveServerAddress("host", explicitPort: 30000)

        XCTAssertEqual(resolved.address, "host")
        XCTAssertEqual(resolved.port, 30000)
        XCTAssertEqual(resolved.originalAddress, "host")
        XCTAssertEqual(resolved.originalPort, 30000)
    }

    func testResolveServerAddress_zeroPortFallsBackToDefault() async {
        let host = "this-host-should-not-resolve.invalid"
        let resolved = await NetworkUtils.resolveServerAddress(host, explicitPort: 0)

        XCTAssertEqual(resolved.address, host)
        XCTAssertEqual(resolved.port, 25565)
        XCTAssertEqual(resolved.originalAddress, host)
        XCTAssertEqual(resolved.originalPort, 25565)
    }

    func testResolveServerAddress_embeddedPortWins() async {
        let resolved = await NetworkUtils.resolveServerAddress("host:30000", explicitPort: 25565)

        XCTAssertEqual(resolved.address, "host")
        XCTAssertEqual(resolved.port, 30000)
        XCTAssertEqual(resolved.originalAddress, "host")
        XCTAssertEqual(resolved.originalPort, 30000)
    }

    func testResolveServerAddress_embeddedDefaultPort() async {
        let resolved = await NetworkUtils.resolveServerAddress("host:25565", explicitPort: 25565)

        XCTAssertEqual(resolved.address, "host")
        XCTAssertEqual(resolved.port, 25565)
        XCTAssertEqual(resolved.originalAddress, "host")
        XCTAssertEqual(resolved.originalPort, 25565)
    }

    func testResolveServerAddress_invalidEmbeddedPortFallsBackToExplicitPort() async {
        let resolved = await NetworkUtils.resolveServerAddress("host:notaport", explicitPort: 40000)

        XCTAssertEqual(resolved.port, 40000)
        XCTAssertEqual(resolved.originalPort, 40000)
    }
}
