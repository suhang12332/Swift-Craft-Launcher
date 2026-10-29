//
//  GameLaunchUseCaseTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

@MainActor
final class GameLaunchUseCaseTests: XCTestCase {
    func testToggleWithMissingPlayerPresentsLaunchError() async {
        let errorHandler = DIContainer.shared.core.errorHandler
        errorHandler.cleanup()

        let useCase = GameLaunchUseCase()
        await useCase.toggleGameState(player: nil, game: makeGame())
        await Task.yield()

        XCTAssertEqual(errorHandler.currentError?.i18nKey, "sidebar.alert.no_player_for_launch.message")
        XCTAssertEqual(errorHandler.currentError?.titleKey, "sidebar.alert.no_player.title")
        errorHandler.cleanup()
    }

    func testToggleIgnoresLaunchWhileAlreadyLaunching() async throws {
        let statusManager = DIContainer.shared.core.gameStatusManager
        let player = try Player(name: "ReentryTest")
        let game = makeGame()
        statusManager.setGameLaunching(gameId: game.id, userId: player.id, isLaunching: true)
        defer {
            statusManager.setGameLaunching(gameId: game.id, userId: player.id, isLaunching: false)
        }

        let useCase = GameLaunchUseCase()
        await useCase.toggleGameState(player: player, game: game)

        XCTAssertTrue(useCase.isLaunching(gameId: game.id, userId: player.id))
    }

    private func makeGame() -> GameVersionInfo {
        GameVersionInfo(
            gameName: "TestGame",
            gameIcon: "",
            gameVersion: "1.20.1",
            assetIndex: "17",
            modLoader: "vanilla",
        )
    }
}
