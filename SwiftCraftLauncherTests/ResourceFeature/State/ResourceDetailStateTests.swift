//
//  ResourceDetailStateTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

@MainActor
final class ResourceDetailStateTests: XCTestCase {
    func testInit_defaultValues() {
        let state = ResourceDetailState()

        XCTAssertEqual(state.selectedItem, .resource(.mod))
        XCTAssertTrue(state.gameType)
        XCTAssertNil(state.gameId)
        XCTAssertEqual(state.gameResourcesType, ResourceType.mod.rawValue)
        XCTAssertNil(state.selectedProjectId)
        XCTAssertNil(state.loadedProjectDetail)
        XCTAssertFalse(state.showInstallSheet)
    }

    func testInit_customValues() {
        let state = ResourceDetailState(
            selectedItem: .game("test-game"),
            gameType: true,
            gameId: "game-id",
            gameResourcesType: "shader",
            selectedProjectId: "proj-id",
        )

        XCTAssertEqual(state.selectedItem, .game("test-game"))
        XCTAssertTrue(state.gameType)
        XCTAssertEqual(state.gameId, "game-id")
        XCTAssertEqual(state.gameResourcesType, "shader")
        XCTAssertEqual(state.selectedProjectId, "proj-id")
    }

    func testClearSelection() {
        let state = ResourceDetailState(
            selectedProjectId: "proj-id",
        )

        state.clearSelection()

        XCTAssertNil(state.selectedProjectId)
        XCTAssertNil(state.loadedProjectDetail)
    }

    func testSelectedProjectId_didSet_clearsDetail() {
        let state = ResourceDetailState()

        state.selectedProjectId = "proj-1"
        state.selectedProjectId = "proj-2"

        XCTAssertNil(state.loadedProjectDetail)
    }
}
