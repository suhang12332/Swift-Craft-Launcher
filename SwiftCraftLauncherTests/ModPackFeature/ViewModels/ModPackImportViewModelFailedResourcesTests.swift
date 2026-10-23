//
//  ModPackImportViewModelFailedResourcesTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import SwiftUI
import XCTest

@MainActor
final class ModPackImportViewModelFailedResourcesTests: XCTestCase {
    func testFailedResources_areSharedWithSheetViewModel() {
        let viewModel = makeViewModel()
        let resource = makeResource()

        viewModel.failedResources = [resource]

        XCTAssertEqual(viewModel.modPackViewModel.failedResources.map(\.id), [resource.id])

        viewModel.modPackViewModel.failedResources = []

        XCTAssertTrue(viewModel.failedResources.isEmpty)
    }

    func testFailedResourcesContinuation_isSharedWithSheetViewModel() {
        let viewModel = makeViewModel()
        var resumedValues: [Bool] = []
        viewModel.failedResourcesContinuation = { resumedValues.append($0) }

        // Cancelling an import aborts failed resources through the sheet view model,
        // so it must hold the same continuation the coordinator is waiting on.
        XCTAssertNotNil(viewModel.modPackViewModel.failedResourcesContinuation)

        viewModel.modPackViewModel.failedResourcesContinuation?(false)

        XCTAssertEqual(resumedValues, [false])
    }

    private func makeViewModel() -> ModPackImportViewModel {
        let configuration = GameFormConfiguration(
            isDownloading: .constant(false),
            isFormValid: .constant(false),
            triggerConfirm: .constant(false),
            triggerCancel: .constant(false),
            onCancel: { },
            onConfirm: { },
        )
        return ModPackImportViewModel(configuration: configuration)
    }

    private func makeResource() -> FailedModPackResource {
        FailedModPackResource(
            projectDetail: makeProjectDetail(),
            resourceType: ResourceType.mod.rawValue,
            gameInfo: GameVersionInfo(
                id: UUID(),
                gameName: "Test Game",
                gameIcon: AppConstants.defaultGameIcon,
                gameVersion: "1.20.1",
                assetIndex: "",
                modLoader: GameLoader.fabric.displayName,
            ),
        )
    }

    private func makeProjectDetail() -> ModrinthProjectDetail {
        ModrinthProjectDetail(
            slug: "test-mod",
            title: "Test Mod",
            description: "",
            categories: [],
            clientSide: "required",
            serverSide: "required",
            body: "",
            additionalCategories: nil,
            issuesUrl: nil,
            sourceUrl: nil,
            wikiUrl: nil,
            discordUrl: nil,
            projectType: "mod",
            downloads: 0,
            iconUrl: nil,
            id: "test-mod",
            team: "team",
            published: Date(timeIntervalSince1970: 0),
            updated: Date(timeIntervalSince1970: 0),
            followers: 0,
            license: nil,
            versions: ["1.20.1"],
            gameVersions: ["1.20.1"],
            loaders: ["fabric"],
            type: nil,
            fileName: nil,
        )
    }
}
