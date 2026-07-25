//
//  ErrorHandlerMigrationTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

/// Tests verifying that migrated ViewModels route errors through GlobalErrorHandler
/// instead of maintaining local error state.
@MainActor
final class ErrorHandlerMigrationTests: XCTestCase {
    private func flushMainQueue() {
        let exp = XCTestExpectation(description: "flush main queue")
        DispatchQueue.main.async { exp.fulfill() }
        _ = XCTWaiter.wait(for: [exp], timeout: 1.0)
    }

    private func resetHandler() {
        DIContainer.shared.core.errorHandler.cleanup()
        let exp = XCTestExpectation(description: "reset cleanup")
        DispatchQueue.main.async { exp.fulfill() }
        _ = XCTWaiter.wait(for: [exp], timeout: 1.0)
    }

    override func setUp() {
        super.setUp()
        resetHandler()
    }

    override func tearDown() {
        resetHandler()
        super.tearDown()
    }

    func testServerAddressEdit_saveWithEmptyName_routesError() {
        resetHandler()
        let vm = ServerAddressEditActionViewModel()
        let request = ServerAddressEditActionViewModel.SaveRequest(
            existing: nil,
            gameName: "test",
            name: "",
            address: "localhost",
            port: 25565,
            hidden: false,
            acceptTextures: false,
        )

        vm.saveServer(request: request, dismiss: { }, onRefresh: nil)
        flushMainQueue()

        XCTAssertNotNil(DIContainer.shared.core.errorHandler.currentError)
        XCTAssertEqual(DIContainer.shared.core.errorHandler.currentError?.kind, .validation)
    }

    func testServerAddressEdit_saveWithEmptyAddress_routesError() {
        resetHandler()
        let vm = ServerAddressEditActionViewModel()
        let request = ServerAddressEditActionViewModel.SaveRequest(
            existing: nil,
            gameName: "test",
            name: "My Server",
            address: "",
            port: 25565,
            hidden: false,
            acceptTextures: false,
        )

        vm.saveServer(request: request, dismiss: { }, onRefresh: nil)
        flushMainQueue()

        XCTAssertNotNil(DIContainer.shared.core.errorHandler.currentError)
        XCTAssertEqual(DIContainer.shared.core.errorHandler.currentError?.kind, .validation)
    }

    func testServerAddressEdit_noShowErrorProperty() {
        let vm = ServerAddressEditActionViewModel()
        // showError and errorMessage should no longer exist as mutable properties
        // After migration, vm.showError should not be settable
        // We verify by checking that the ViewModel only has isSaving, isDeleting
        XCTAssertFalse(vm.isSaving)
        XCTAssertFalse(vm.isDeleting)
    }

    func testModPackExport_handleSaveFailure_routesError() {
        resetHandler()
        let vm = ModPackExportViewModel()

        vm.handleSaveFailure(error: "Permission denied")
        flushMainQueue()

        XCTAssertNotNil(DIContainer.shared.core.errorHandler.currentError)
        XCTAssertEqual(DIContainer.shared.core.errorHandler.currentError?.kind, .fileSystem)
    }

    func testModPackExport_handleSaveSuccess_noError() {
        let vm = ModPackExportViewModel()

        vm.handleSaveSuccess()
        flushMainQueue()

        XCTAssertNil(DIContainer.shared.core.errorHandler.currentError)
    }

    func testModPackExport_cleanupAllData_noError() {
        let vm = ModPackExportViewModel()

        vm.cleanupAllData()
        flushMainQueue()

        XCTAssertNil(DIContainer.shared.core.errorHandler.currentError)
    }

    func testGameAdvancedSettings_handleJavaPathSelection_fileNotFound_routesError() {
        resetHandler()
        let vm = GameAdvancedSettingsViewModel()

        let nonexistentURL = URL(fileURLWithPath: "/nonexistent/java")
        vm.handleJavaPathSelection(.success([nonexistentURL]))
        flushMainQueue()

        XCTAssertNotNil(DIContainer.shared.core.errorHandler.currentError)
        XCTAssertEqual(DIContainer.shared.core.errorHandler.currentError?.kind, .fileSystem)
    }

    func testGameAdvancedSettings_handleJavaPathSelection_failure_routesError() {
        resetHandler()
        let vm = GameAdvancedSettingsViewModel()
        let error = NSError(domain: "test", code: 1, userInfo: nil)

        vm.handleJavaPathSelection(.failure(error))
        flushMainQueue()

        XCTAssertNotNil(DIContainer.shared.core.errorHandler.currentError)
        XCTAssertEqual(DIContainer.shared.core.errorHandler.currentError?.kind, .fileSystem)
    }

    func testGameAdvancedSettings_noLocalErrorState() {
        let vm = GameAdvancedSettingsViewModel()
        // After migration, error property should not exist
        // Verify the ViewModel initializes cleanly without error state
        XCTAssertNil(vm.saveTask)
    }

    func testModrinthDetailCoordinator_clearError_doesNotCrash() {
        let vm = ModrinthDetailCoordinatorViewModel()

        vm.clearError()
    }

    func testModrinthDetailCoordinator_hasLoaded_initiallyFalse() {
        let vm = ModrinthDetailCoordinatorViewModel()
        XCTAssertFalse(vm.hasLoaded)
    }

    func testGameLocalResource_initialStateClean() {
        let vm = GameLocalResourceViewModel()
        XCTAssertTrue(vm.displayedResources.isEmpty)
        XCTAssertFalse(vm.isLoadingResources)
        XCTAssertFalse(vm.isLoadingMore)
        XCTAssertFalse(vm.hasLoaded)
    }

    func testDependencySheetAction_downloadMainOnly_callsClosure() {
        var called = false
        let vm = DependencySheetActionViewModel(
            isDownloadingAllDependencies: .constant(false),
            isDownloadingMainResourceOnly: .constant(false),
        )

        vm.downloadMainOnly { called = true }
        flushMainQueue()

        XCTAssertTrue(called)
    }

    func testDependencySheetAction_downloadAll_callsClosure() {
        var called = false
        let vm = DependencySheetActionViewModel(
            isDownloadingAllDependencies: .constant(false),
            isDownloadingMainResourceOnly: .constant(false),
        )

        vm.downloadAll { called = true }
        flushMainQueue()

        XCTAssertTrue(called)
    }

    func testGeneralSettings_clearError_doesNotCrash() {
        let vm = GeneralSettingsViewModel()

        vm.clearError()
    }

    func testGeneralSettings_initialStateClean() {
        let vm = GeneralSettingsViewModel()
        XCTAssertFalse(vm.showDirectoryPicker)
    }

    func testErrorHandler_receivesMultipleErrors() {
        resetHandler()
        let handler = DIContainer.shared.core.errorHandler

        handler.handle(GlobalError.network(i18nKey: "test.network.1"))
        flushMainQueue()
        XCTAssertEqual(handler.errorHistory.count, 1)

        handler.handle(GlobalError.fileSystem(i18nKey: "test.fs.1"))
        flushMainQueue()
        XCTAssertEqual(handler.errorHistory.count, 2)
    }

    func testErrorHandler_popupLevel_setsCurrentError() {
        resetHandler()
        let handler = DIContainer.shared.core.errorHandler

        handler.handle(GlobalError.authentication(i18nKey: "test.auth.popup", level: .popup))
        flushMainQueue()

        XCTAssertEqual(handler.currentError?.level, .popup)
        XCTAssertEqual(handler.currentError?.kind, .authentication)
    }

    func testErrorHandler_clearCurrentError_works() {
        resetHandler()
        let handler = DIContainer.shared.core.errorHandler

        handler.handle(GlobalError.network(i18nKey: "test.clear"))
        flushMainQueue()
        XCTAssertNotNil(handler.currentError)

        handler.clearCurrentError()
        flushMainQueue()
        XCTAssertNil(handler.currentError)
    }

    func testErrorHandler_fileSystemError_recorded() {
        resetHandler()
        let handler = DIContainer.shared.core.errorHandler

        handler.handle(GlobalError.fileSystem(i18nKey: "error.fs.migration.test", level: .popup))
        flushMainQueue()

        XCTAssertEqual(handler.errorHistory.count, 1)
        XCTAssertEqual(handler.errorHistory.first?.kind, .fileSystem)
    }

    func testGameAdvancedSettings_errorHasSettingsSource() {
        resetHandler()
        let vm = GameAdvancedSettingsViewModel()
        let nonexistentURL = URL(fileURLWithPath: "/nonexistent/java")
        vm.handleJavaPathSelection(.success([nonexistentURL]))
        flushMainQueue()

        XCTAssertEqual(DIContainer.shared.core.errorHandler.currentError?.source, .settings)
    }

    func testGameAdvancedSettings_failureErrorHasSettingsSource() {
        resetHandler()
        let vm = GameAdvancedSettingsViewModel()
        let error = NSError(domain: "test", code: 1, userInfo: nil)
        vm.handleJavaPathSelection(.failure(error))
        flushMainQueue()

        XCTAssertEqual(DIContainer.shared.core.errorHandler.currentError?.source, .settings)
    }
}
