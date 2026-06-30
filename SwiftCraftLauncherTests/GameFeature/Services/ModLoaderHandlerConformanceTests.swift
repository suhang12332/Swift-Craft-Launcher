//
//  ModLoaderHandlerConformanceTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class ModLoaderHandlerConformanceTests: XCTestCase {

    func testFabricLoaderService_conformsToModLoaderHandler() {
        let _: any ModLoaderHandler.Type = FabricLoaderService.self
        XCTAssertTrue(true)
    }

    func testForgeLoaderService_conformsToModLoaderHandler() {
        let _: any ModLoaderHandler.Type = ForgeLoaderService.self
        XCTAssertTrue(true)
    }

    func testNeoForgeLoaderService_conformsToModLoaderHandler() {
        let _: any ModLoaderHandler.Type = NeoForgeLoaderService.self
        XCTAssertTrue(true)
    }

    func testQuiltLoaderService_conformsToModLoaderHandler() {
        let _: any ModLoaderHandler.Type = QuiltLoaderService.self
        XCTAssertTrue(true)
    }

    func testAllLoaders_returnSameTupleShape() {
        // Verify all four services have the same static method signatures
        // by checking they can be assigned to the same protocol type
        let handlers: [any ModLoaderHandler.Type] = [
            FabricLoaderService.self,
            ForgeLoaderService.self,
            NeoForgeLoaderService.self,
            QuiltLoaderService.self,
        ]
        XCTAssertEqual(handlers.count, 4)
    }
}
