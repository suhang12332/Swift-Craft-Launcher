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
    private func storeDummyProcess(
        in store: GameSessionStore,
        gameId: String = "game",
        userId: String = "player",
    ) -> Process {
        let process = Process()
        store.storeProcess(
            gameId: gameId,
            userId: userId,
            gameDirectory: URL(fileURLWithPath: "/tmp"),
            process: process,
        )
        return process
    }

    func testStateIsScopedByPlayer() {
        let store = GameSessionStore()
        _ = storeDummyProcess(in: store, userId: "player-1")
        store.setGameRunning(gameId: "game", userId: "player-1", isRunning: true)
        store.setGameLaunching(gameId: "game", userId: "player-1", isLaunching: true)

        XCTAssertTrue(store.cachedIsGameRunning(gameId: "game", userId: "player-1"))
        XCTAssertTrue(store.isGameLaunching(gameId: "game", userId: "player-1"))
        XCTAssertFalse(store.cachedIsGameRunning(gameId: "game", userId: "player-2"))
        XCTAssertFalse(store.isGameLaunching(gameId: "game", userId: "player-2"))
    }

    func testRemoveGameStateClearsRunningAndLaunchingStates() {
        let store = GameSessionStore()
        _ = storeDummyProcess(in: store)
        store.setGameRunning(gameId: "game", userId: "player", isRunning: true)
        store.setGameLaunching(gameId: "game", userId: "player", isLaunching: true)

        store.removeGameState(gameId: "game")

        XCTAssertFalse(store.cachedIsGameRunning(gameId: "game", userId: "player"))
        XCTAssertFalse(store.isGameLaunching(gameId: "game", userId: "player"))
    }

    func testAuthoritativeRunningCheckClearsStaleCache() {
        let store = GameSessionStore()
        _ = storeDummyProcess(in: store)
        store.setGameRunning(gameId: "game", userId: "player", isRunning: true)

        XCTAssertFalse(store.refreshGameStatus(gameId: "game", userId: "player"))
        XCTAssertFalse(store.cachedIsGameRunning(gameId: "game", userId: "player"))
    }

    func testSetRunningDoesNotCreateSession() {
        let store = GameSessionStore()
        store.setGameRunning(gameId: "game", userId: "player", isRunning: true)

        XCTAssertFalse(store.cachedIsGameRunning(gameId: "game", userId: "player"))
    }

    func testMarkProcessRunningRequiresCurrentProcess() {
        let store = GameSessionStore()
        let process = storeDummyProcess(in: store)

        store.markProcessRunning(gameId: "game", userId: "player", process: Process())
        XCTAssertFalse(store.cachedIsGameRunning(gameId: "game", userId: "player"))

        store.markProcessRunning(gameId: "game", userId: "player", process: process)
        XCTAssertTrue(store.cachedIsGameRunning(gameId: "game", userId: "player"))
    }

    func testNormalExitIsNotAbnormal() {
        XCTAssertFalse(GameSessionStore.didExitAbnormally(reason: .exit, status: 0))
    }

    func testNonZeroExitIsAbnormal() {
        XCTAssertTrue(GameSessionStore.didExitAbnormally(reason: .exit, status: 1))
    }

    func testUncaughtSignalIsAbnormal() {
        XCTAssertTrue(GameSessionStore.didExitAbnormally(reason: .uncaughtSignal, status: 9))
    }
}
