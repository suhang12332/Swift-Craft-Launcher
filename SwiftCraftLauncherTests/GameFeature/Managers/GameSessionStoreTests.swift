//
//  GameSessionStoreTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

@MainActor
final class GameSessionStoreTests: XCTestCase {
    func testStateIsScopedByPlayer() {
        let store = GameSessionStore()
        store.setGameRunning(gameId: "game", userId: "player-1", isRunning: true)
        store.setGameLaunching(gameId: "game", userId: "player-1", isLaunching: true)

        XCTAssertTrue(store.cachedIsGameRunning(gameId: "game", userId: "player-1"))
        XCTAssertTrue(store.isGameLaunching(gameId: "game", userId: "player-1"))
        XCTAssertFalse(store.cachedIsGameRunning(gameId: "game", userId: "player-2"))
        XCTAssertFalse(store.isGameLaunching(gameId: "game", userId: "player-2"))
    }

    func testRemoveGameStateClearsRunningAndLaunchingStates() {
        let store = GameSessionStore()
        store.setGameRunning(gameId: "game", userId: "player", isRunning: true)
        store.setGameLaunching(gameId: "game", userId: "player", isLaunching: true)

        store.removeGameState(gameId: "game")

        XCTAssertFalse(store.cachedIsGameRunning(gameId: "game", userId: "player"))
        XCTAssertFalse(store.isGameLaunching(gameId: "game", userId: "player"))
    }

    func testAuthoritativeRunningCheckClearsStaleCache() {
        let store = GameSessionStore()
        store.setGameRunning(gameId: "game", userId: "player", isRunning: true)

        XCTAssertFalse(store.refreshGameStatus(gameId: "game", userId: "player"))
        XCTAssertFalse(store.cachedIsGameRunning(gameId: "game", userId: "player"))
    }
}
