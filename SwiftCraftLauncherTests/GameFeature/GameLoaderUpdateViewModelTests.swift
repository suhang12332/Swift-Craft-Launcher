//
//  GameLoaderUpdateViewModelTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

@MainActor
final class GameLoaderUpdateViewModelTests: XCTestCase {
    private func makeGame(
        modLoader: String = GameLoader.fabric.displayName,
        modVersion: String = "0.16.0",
    ) -> GameVersionInfo {
        GameVersionInfo(
            gameName: "TestGame",
            gameIcon: "icon.png",
            gameVersion: "1.20.1",
            modVersion: modVersion,
            modClassPath: "/libs",
            assetIndex: "17",
            modLoader: modLoader,
            xms: 1024,
            xmx: 4096,
            javaVersion: 17,
        )
    }

    func testInit_fabricGame_defaultsToExistingLoaderAndVersion() {
        let game = makeGame(modLoader: "fabric", modVersion: "0.16.0")
        let vm = GameLoaderUpdateViewModel(existingGame: game)

        XCTAssertEqual(vm.selectedModLoader, "fabric")
        XCTAssertEqual(vm.selectedLoaderVersion, "0.16.0")
        XCTAssertEqual(vm.existingGame.id, game.id)
        XCTAssertEqual(vm.existingGame.gameVersion, "1.20.1")
    }

    func testInit_vanillaGame_emptyLoaderVersion() {
        let game = makeGame(modLoader: GameLoader.vanilla.displayName, modVersion: "")
        let vm = GameLoaderUpdateViewModel(existingGame: game)

        XCTAssertEqual(vm.selectedModLoader, "vanilla")
        XCTAssertEqual(vm.selectedLoaderVersion, "")
    }

    func testSelectedModLoader_isFixedToExistingGameLoader() {
        let game = makeGame(modLoader: "forge", modVersion: "47.0.1")
        let vm = GameLoaderUpdateViewModel(existingGame: game)

        // For non-vanilla games, selectedModLoader defaults to the existing loader
        // and should not be changed by the user.
        XCTAssertEqual(vm.selectedModLoader, "forge")
        XCTAssertEqual(vm.selectedModLoader, vm.existingGame.modLoader)
    }

    func testIsFormValid_fabric_emptyVersion_returnsFalse() {
        let vm = GameLoaderUpdateViewModel(existingGame: makeGame(modLoader: "fabric", modVersion: ""))
        vm.selectedLoaderVersion = ""
        XCTAssertFalse(vm.isFormValid)
    }

    func testIsFormValid_fabric_withVersion_returnsTrue() {
        let vm = GameLoaderUpdateViewModel(existingGame: makeGame(modLoader: "fabric", modVersion: "0.16.0"))
        vm.selectedLoaderVersion = "0.16.5"
        XCTAssertTrue(vm.isFormValid)
    }

    func testIsFormValid_forge_withVersion_returnsTrue() {
        let vm = GameLoaderUpdateViewModel(existingGame: makeGame(modLoader: "forge", modVersion: "47.0.1"))
        vm.selectedLoaderVersion = "47.1.0"
        XCTAssertTrue(vm.isFormValid)
    }

    func testIsFormValid_loadingVersions_returnsFalse() {
        let vm = GameLoaderUpdateViewModel(existingGame: makeGame(modLoader: "fabric", modVersion: "0.16.0"))
        vm.selectedLoaderVersion = "0.16.0"
        vm.isLoadingLoaderVersions = true
        XCTAssertFalse(vm.isFormValid)
    }

    func testIsFormValid_updating_returnsFalse() {
        let vm = GameLoaderUpdateViewModel(existingGame: makeGame(modLoader: "fabric", modVersion: "0.16.0"))
        vm.selectedLoaderVersion = "0.16.0"
        vm.gameSetupService.downloadState.isDownloading = true
        XCTAssertFalse(vm.isFormValid)
    }

    func testCurrentLoaderDescription_vanilla() {
        let vm = GameLoaderUpdateViewModel(
            existingGame: makeGame(modLoader: GameLoader.vanilla.displayName, modVersion: ""),
        )
        XCTAssertEqual(vm.currentLoaderDescription, "Vanilla")
    }

    func testCurrentLoaderDescription_fabricWithVersion() {
        let vm = GameLoaderUpdateViewModel(existingGame: makeGame(modLoader: "fabric", modVersion: "0.16.0"))
        XCTAssertEqual(vm.currentLoaderDescription, "Fabric 0.16.0")
    }

    func testCurrentLoaderDescription_forgeNoVersion() {
        let vm = GameLoaderUpdateViewModel(existingGame: makeGame(modLoader: "forge", modVersion: ""))
        XCTAssertEqual(vm.currentLoaderDescription, "Forge")
    }

    func testCurrentLoaderDescription_neoforgeWithVersion() {
        let vm = GameLoaderUpdateViewModel(
            existingGame: makeGame(modLoader: "neoforge", modVersion: "21.0.1"),
        )
        XCTAssertEqual(vm.currentLoaderDescription, "NeoForge 21.0.1")
    }

    func testIsUpdating_reflectsDownloadState() {
        let vm = GameLoaderUpdateViewModel(existingGame: makeGame(modLoader: "fabric", modVersion: "0.16.0"))
        XCTAssertFalse(vm.isUpdating)
        vm.gameSetupService.downloadState.isDownloading = true
        XCTAssertTrue(vm.isUpdating)
        XCTAssertTrue(vm.shouldShowProgress)
    }

    func testCancel_whenNotUpdating_isNoOp() {
        let vm = GameLoaderUpdateViewModel(existingGame: makeGame(modLoader: "fabric", modVersion: "0.16.0"))
        vm.cancel() // should not crash when nothing is running
        XCTAssertFalse(vm.isUpdating)
    }

    // MARK: - Vanilla game: add loader

    func testCanChangeLoaderType_vanilla_returnsTrue() {
        let vm = GameLoaderUpdateViewModel(existingGame: makeGame(modLoader: GameLoader.vanilla.displayName))
        XCTAssertTrue(vm.canChangeLoaderType)
    }

    func testCanChangeLoaderType_nonVanilla_returnsFalse() {
        let vm = GameLoaderUpdateViewModel(existingGame: makeGame(modLoader: "fabric"))
        XCTAssertFalse(vm.canChangeLoaderType)
    }

    func testAvailableLoaderTypes_excludesVanilla() {
        let vm = GameLoaderUpdateViewModel(existingGame: makeGame())
        XCTAssertFalse(vm.availableLoaderTypes.contains(.vanilla))
        XCTAssertEqual(vm.availableLoaderTypes.count, GameLoader.allCases.count - 1)
    }

    func testIsFormValid_vanilla_withVersion_returnsTrue() {
        let vm = GameLoaderUpdateViewModel(existingGame: makeGame(modLoader: GameLoader.vanilla.displayName))
        vm.selectedModLoader = "fabric"
        vm.selectedLoaderVersion = "0.16.5"
        XCTAssertTrue(vm.isFormValid)
    }

    func testIsFormValid_vanilla_emptyVersion_returnsFalse() {
        let vm = GameLoaderUpdateViewModel(existingGame: makeGame(modLoader: GameLoader.vanilla.displayName))
        vm.selectedModLoader = "fabric"
        vm.selectedLoaderVersion = ""
        XCTAssertFalse(vm.isFormValid)
    }

    func testSelectedModLoader_vanilla_canBeChanged() {
        let vm = GameLoaderUpdateViewModel(existingGame: makeGame(modLoader: GameLoader.vanilla.displayName))
        XCTAssertEqual(vm.selectedModLoader, "vanilla")
        vm.selectedModLoader = "forge"
        XCTAssertEqual(vm.selectedModLoader, "forge")
    }
}
