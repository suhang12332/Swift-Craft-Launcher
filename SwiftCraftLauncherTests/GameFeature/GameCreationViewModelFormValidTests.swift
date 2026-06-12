import XCTest
import SwiftUI
@testable import SwiftCraftLauncher

@MainActor
final class GameCreationViewModelFormValidTests: XCTestCase {

    private func makeViewModel() -> GameCreationViewModel {
        let config = GameFormConfiguration(
            isDownloading: .constant(false),
            isFormValid: .constant(false),
            triggerConfirm: .constant(false),
            triggerCancel: .constant(false),
            onCancel: {},
            onConfirm: {}
        )
        return GameCreationViewModel(configuration: config)
    }

    func testComputeIsFormValid_vanillaLoader_noLoaderVersion_returnsTrue() {
        let vm = makeViewModel()
        vm.gameNameValidator.gameName = "TestGame"
        vm.gameNameValidator.isGameNameDuplicate = false
        vm.selectedModLoader = GameLoader.vanilla.displayName
        vm.selectedLoaderVersion = ""
        XCTAssertTrue(vm.computeIsFormValid())
    }

    func testComputeIsFormValid_fabricLoader_emptyLoaderVersion_returnsFalse() {
        let vm = makeViewModel()
        vm.gameNameValidator.gameName = "TestGame"
        vm.gameNameValidator.isGameNameDuplicate = false
        vm.selectedModLoader = GameLoader.fabric.displayName
        vm.selectedLoaderVersion = ""
        XCTAssertFalse(vm.computeIsFormValid())
    }

    func testComputeIsFormValid_fabricLoader_withLoaderVersion_returnsTrue() {
        let vm = makeViewModel()
        vm.gameNameValidator.gameName = "TestGame"
        vm.gameNameValidator.isGameNameDuplicate = false
        vm.selectedModLoader = GameLoader.fabric.displayName
        vm.selectedLoaderVersion = "0.14.0"
        XCTAssertTrue(vm.computeIsFormValid())
    }

    func testComputeIsFormValid_forgeLoader_emptyLoaderVersion_returnsFalse() {
        let vm = makeViewModel()
        vm.gameNameValidator.gameName = "TestGame"
        vm.gameNameValidator.isGameNameDuplicate = false
        vm.selectedModLoader = GameLoader.forge.displayName
        vm.selectedLoaderVersion = ""
        XCTAssertFalse(vm.computeIsFormValid())
    }

    func testComputeIsFormValid_neoforgeLoader_withLoaderVersion_returnsTrue() {
        let vm = makeViewModel()
        vm.gameNameValidator.gameName = "TestGame"
        vm.gameNameValidator.isGameNameDuplicate = false
        vm.selectedModLoader = GameLoader.neoforge.displayName
        vm.selectedLoaderVersion = "21.0.1"
        XCTAssertTrue(vm.computeIsFormValid())
    }

    func testComputeIsFormValid_quiltLoader_withLoaderVersion_returnsTrue() {
        let vm = makeViewModel()
        vm.gameNameValidator.gameName = "TestGame"
        vm.gameNameValidator.isGameNameDuplicate = false
        vm.selectedModLoader = GameLoader.quilt.displayName
        vm.selectedLoaderVersion = "0.26.0"
        XCTAssertTrue(vm.computeIsFormValid())
    }

    func testComputeIsFormValid_emptyName_returnsFalse() {
        let vm = makeViewModel()
        vm.gameNameValidator.gameName = ""
        vm.selectedModLoader = GameLoader.vanilla.displayName
        XCTAssertFalse(vm.computeIsFormValid())
    }

    func testComputeIsFormValid_duplicateName_returnsFalse() {
        let vm = makeViewModel()
        vm.gameNameValidator.gameName = "TestGame"
        vm.gameNameValidator.isGameNameDuplicate = true
        vm.selectedModLoader = GameLoader.vanilla.displayName
        XCTAssertFalse(vm.computeIsFormValid())
    }

    func testComputeIsFormValid_vanillaLoader_withLoaderVersion_returnsTrue() {
        let vm = makeViewModel()
        vm.gameNameValidator.gameName = "TestGame"
        vm.gameNameValidator.isGameNameDuplicate = false
        vm.selectedModLoader = GameLoader.vanilla.displayName
        vm.selectedLoaderVersion = "some-version"
        XCTAssertTrue(vm.computeIsFormValid())
    }
}
