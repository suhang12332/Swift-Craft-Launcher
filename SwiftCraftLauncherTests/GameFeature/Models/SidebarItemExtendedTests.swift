//
//  SidebarItemExtendedTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class SidebarItemExtendedTests: XCTestCase {

    func testTitle_game() {
        let item = SidebarItem.game("test-game")
        XCTAssertEqual(item.title, "test-game")
    }

    func testTitle_resource_mod() {
        let item = SidebarItem.resource(.mod)
        XCTAssertFalse(item.title.isEmpty)
    }

    func testTitle_resource_shader() {
        let item = SidebarItem.resource(.shader)
        XCTAssertFalse(item.title.isEmpty)
    }

    func testTitle_resource_resourcepack() {
        let item = SidebarItem.resource(.resourcepack)
        XCTAssertFalse(item.title.isEmpty)
    }

    func testTitle_resource_modpack() {
        let item = SidebarItem.resource(.modpack)
        XCTAssertFalse(item.title.isEmpty)
    }

    func testTitle_resource_datapack() {
        let item = SidebarItem.resource(.datapack)
        XCTAssertFalse(item.title.isEmpty)
    }

    func testTitle_resource_minecraftJavaServer() {
        let item = SidebarItem.resource(.minecraftJavaServer)
        XCTAssertFalse(item.title.isEmpty)
    }

    func testEquatable_game_sameId() {
        let a = SidebarItem.game("id1")
        let b = SidebarItem.game("id1")
        XCTAssertEqual(a, b)
    }

    func testEquatable_game_differentId() {
        let a = SidebarItem.game("id1")
        let b = SidebarItem.game("id2")
        XCTAssertNotEqual(a, b)
    }

    func testEquatable_resource_sameType() {
        let a = SidebarItem.resource(.mod)
        let b = SidebarItem.resource(.mod)
        XCTAssertEqual(a, b)
    }

    func testEquatable_resource_differentType() {
        let a = SidebarItem.resource(.mod)
        let b = SidebarItem.resource(.shader)
        XCTAssertNotEqual(a, b)
    }

    func testEquatable_gameVsResource() {
        let a = SidebarItem.game("mod")
        let b = SidebarItem.resource(.mod)
        XCTAssertNotEqual(a, b)
    }

    func testResourceType_localizedName_notEmpty() {
        for type in ResourceType.allCases {
            XCTAssertFalse(type.localizedName.isEmpty, "localizedName for \(type.rawValue) should not be empty")
        }
    }

    func testResourceType_localizedName_different() {
        let names = ResourceType.allCases.map { $0.localizedName }
        let uniqueNames = Set(names)
        XCTAssertEqual(names.count, uniqueNames.count, "All ResourceType localizedName should be unique")
    }

    func testResourceType_rawValue() {
        for type in ResourceType.allCases {
            XCTAssertEqual(type.rawValue, type.rawValue)
        }
    }

    func testResourceType_caseIterable_allPresent() {
        let allCases = ResourceType.allCases
        XCTAssertEqual(allCases.count, 6)
        XCTAssertTrue(allCases.contains(.mod))
        XCTAssertTrue(allCases.contains(.datapack))
        XCTAssertTrue(allCases.contains(.shader))
        XCTAssertTrue(allCases.contains(.resourcepack))
        XCTAssertTrue(allCases.contains(.modpack))
        XCTAssertTrue(allCases.contains(.minecraftJavaServer))
    }
}
