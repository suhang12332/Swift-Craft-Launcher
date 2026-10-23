//
//  ResourceInstallViewModelTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

@MainActor
final class ResourceInstallViewModelTests: XCTestCase {
    func testFixedGame_isSelectedAndResolved() {
        let game = makeGame()
        let viewModel = makeViewModel(fixedGame: game)

        XCTAssertEqual(viewModel.selectedGame?.gameName, game.gameName)
        XCTAssertEqual(viewModel.resolvedGame?.gameName, game.gameName)
    }

    func testFixedGame_isRestoredAfterCleanup() {
        let game = makeGame()
        let viewModel = makeViewModel(fixedGame: game)

        viewModel.selectedGame = makeGame(name: "Other Game")
        viewModel.mainVersionId = "version-id"
        viewModel.dependencyState.isLoading = true

        viewModel.cleanup()

        XCTAssertEqual(viewModel.selectedGame?.gameName, game.gameName)
        XCTAssertNil(viewModel.selectedVersion)
        XCTAssertTrue(viewModel.availableVersions.isEmpty)
        XCTAssertEqual(viewModel.mainVersionId, "")
        XCTAssertFalse(viewModel.dependencyState.isLoading)
        XCTAssertTrue(viewModel.dependencyState.dependencies.isEmpty)
    }

    func testNoFixedGame_startsWithNoSelection() {
        let viewModel = makeViewModel(fixedGame: nil)

        XCTAssertNil(viewModel.selectedGame)
        XCTAssertNil(viewModel.resolvedGame)
        XCTAssertTrue(viewModel.hasCompatibleGames)
        XCTAssertFalse(viewModel.isUpdateMode)
    }

    func testOnVersionChanged_nonMod_clearsDependencyState() {
        let viewModel = makeViewModel(
            resourceType: ResourceType.resourcepack.rawValue,
            fixedGame: makeGame(),
        )
        viewModel.dependencyState.isLoading = true

        viewModel.onVersionChanged(nil)

        XCTAssertNil(viewModel.selectedVersion)
        XCTAssertFalse(viewModel.dependencyState.isLoading)
        XCTAssertTrue(viewModel.dependencyState.dependencies.isEmpty)
    }

    func testInstallSingleResource_withoutGame_doesNotStart() {
        let viewModel = makeViewModel(fixedGame: nil)
        var dismissed = false

        viewModel.installSingleResource {
            dismissed = true
        }

        XCTAssertFalse(viewModel.isDownloadingAll)
        XCTAssertFalse(dismissed)
    }

    func testConfiguration_defaults() {
        let configuration = ResourceInstallViewModel.Configuration()

        XCTAssertFalse(configuration.isUpdateMode)
        XCTAssertTrue(configuration.hasCompatibleGames)
        XCTAssertFalse(configuration.dismissOnFailure)
        XCTAssertNil(configuration.onSuccess)
    }

    func testIsInstallLoading_coversVersionDownloadAndDependencyLoading() {
        let viewModel = makeViewModel(fixedGame: makeGame())
        XCTAssertFalse(viewModel.isInstallLoading)

        viewModel.isLoadingVersions = true
        XCTAssertTrue(viewModel.isInstallLoading)

        viewModel.isLoadingVersions = false
        viewModel.dependencyState.isLoading = true
        XCTAssertTrue(viewModel.isInstallLoading)

        viewModel.dependencyState.isLoading = false
        viewModel.isDownloadingAll = true
        XCTAssertTrue(viewModel.isInstallLoading)
    }

    func testCleanup_clearsVersionLoading() {
        let viewModel = makeViewModel(fixedGame: makeGame())
        viewModel.isLoadingVersions = true

        viewModel.cleanup()

        XCTAssertFalse(viewModel.isLoadingVersions)
    }

    private func makeViewModel(
        resourceType: String = ResourceType.mod.rawValue,
        fixedGame: GameVersionInfo?,
    ) -> ResourceInstallViewModel {
        ResourceInstallViewModel(
            project: makeProject(),
            resourceType: resourceType,
            fixedGame: fixedGame,
        )
    }

    private func makeProject() -> ModrinthProject {
        ModrinthProject(
            projectId: "project-id",
            projectType: "mod",
            slug: "test-project",
            author: "author",
            title: "Test Project",
            description: "",
            categories: [],
            displayCategories: [],
            versions: ["1.20.1"],
            downloads: 0,
            follows: 0,
            iconUrl: nil,
            license: "",
            clientSide: "required",
            serverSide: "required",
            fileName: nil,
        )
    }

    private func makeGame(name: String = "Test Game") -> GameVersionInfo {
        GameVersionInfo(
            id: UUID(),
            gameName: name,
            gameIcon: AppConstants.defaultGameIcon,
            gameVersion: "1.20.1",
            assetIndex: "",
            modLoader: GameLoader.fabric.displayName,
        )
    }
}
