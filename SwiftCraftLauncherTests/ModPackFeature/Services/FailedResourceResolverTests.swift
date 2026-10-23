//
//  FailedResourceResolverTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

@MainActor
final class FailedResourceResolverTests: XCTestCase {
    func testPresentFailedResources_emptyWithoutHandler_returnsTrue() async {
        let result = await FailedResourceResolver.presentFailedResources(
            [],
            onShowFailedResources: nil,
        )

        XCTAssertTrue(result)
    }

    func testPresentFailedResources_nonEmptyWithoutHandler_returnsFalse() async {
        let result = await FailedResourceResolver.presentFailedResources(
            [makeResource()],
            onShowFailedResources: nil,
        )

        XCTAssertFalse(result)
    }

    func testPresentFailedResources_returnsHandlerDecision() async {
        var handlerCalled = false

        let result = await FailedResourceResolver.presentFailedResources(
            [makeResource()],
        ) { _, continuation in
            handlerCalled = true
            continuation(true)
        }

        XCTAssertTrue(result)
        XCTAssertTrue(handlerCalled)
    }

    func testPresentFailedResources_forwardsFailedResources() async {
        var receivedCount = 0

        _ = await FailedResourceResolver.presentFailedResources(
            [makeResource(), makeResource()],
        ) { resources, continuation in
            receivedCount = resources.count
            continuation(false)
        }

        XCTAssertEqual(receivedCount, 2)
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
