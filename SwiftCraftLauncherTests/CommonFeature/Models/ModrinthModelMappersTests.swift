//
//  ModrinthModelMappersTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class ModrinthModelMappersTests: XCTestCase {

    func testModrinthProject_fromDetail() throws {
        let detail = try makeDetail(DetailParams(
            id: "proj-1",
            slug: "my-mod",
            title: "My Mod",
            description: "A great mod",
            categories: ["fabric", "library"],
            projectType: "mod",
            downloads: 1000,
            team: "Team1",
            license: "MIT"
        ))

        let project = ModrinthProject.from(detail: detail)

        XCTAssertEqual(project.projectId, "proj-1")
        XCTAssertEqual(project.slug, "my-mod")
        XCTAssertEqual(project.title, "My Mod")
        XCTAssertEqual(project.description, "A great mod")
        XCTAssertEqual(project.categories, ["fabric", "library"])
        XCTAssertEqual(project.projectType, "mod")
        XCTAssertEqual(project.downloads, 1000)
        XCTAssertEqual(project.author, "Team1")
        XCTAssertEqual(project.license, "MIT")
        XCTAssertEqual(project.clientSide, "required")
        XCTAssertEqual(project.serverSide, "required")
    }

    func testModrinthProject_fromDetail_nilLicense() throws {
        let detail = try makeDetail(DetailParams(
            id: "proj-2",
            slug: "mod2",
            title: "Mod2",
            description: "desc",
            categories: [],
            projectType: "mod",
            downloads: 500,
            team: "Team2",
            license: nil
        ))

        let project = ModrinthProject.from(detail: detail)

        XCTAssertEqual(project.license, "")
    }

    func testModrinthProject_fromDetail_additionalCategories() throws {
        let detail = try makeDetail(DetailParams(
            id: "proj-3",
            slug: "mod3",
            title: "Mod3",
            description: "desc",
            categories: ["fabric"],
            additionalCategories: ["library", "utility"],
            projectType: "mod",
            downloads: 100,
            team: "Team3",
            license: nil
        ))

        let project = ModrinthProject.from(detail: detail)

        XCTAssertEqual(project.displayCategories, ["library", "utility"])
    }

    private struct DetailParams {
        var id: String
        var slug: String
        var title: String
        var description: String
        var categories: [String]
        var additionalCategories: [String]?
        var projectType: String
        var downloads: Int
        var team: String
        var license: String?
    }

    private func makeDetail(_ p: DetailParams) throws -> ModrinthProjectDetail {
        let licenseObj: License? = p.license.map { License(id: "mit", name: $0, url: nil) }

        return ModrinthProjectDetail(
            slug: p.slug,
            title: p.title,
            description: p.description,
            categories: p.categories,
            clientSide: "required",
            serverSide: "required",
            body: "",
            additionalCategories: p.additionalCategories,
            issuesUrl: nil,
            sourceUrl: nil,
            wikiUrl: nil,
            discordUrl: nil,
            projectType: p.projectType,
            downloads: p.downloads,
            iconUrl: nil,
            id: p.id,
            team: p.team,
            published: Date(),
            updated: Date(),
            followers: 0,
            license: licenseObj,
            versions: ["1.20.1"],
            gameVersions: ["1.20.1"],
            loaders: ["fabric"],
            type: nil,
            fileName: nil
        )
    }
}
