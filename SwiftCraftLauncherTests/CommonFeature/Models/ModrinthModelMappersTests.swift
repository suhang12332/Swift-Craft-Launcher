import XCTest
@testable import SwiftCraftLauncher

final class ModrinthModelMappersTests: XCTestCase {

    // MARK: - ModrinthProject.from(detail:)

    func testModrinthProject_fromDetail() throws {
        let detail = try makeDetail(
            id: "proj-1",
            slug: "my-mod",
            title: "My Mod",
            description: "A great mod",
            categories: ["fabric", "library"],
            projectType: "mod",
            downloads: 1000,
            team: "Team1",
            license: "MIT"
        )

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
        let detail = try makeDetail(
            id: "proj-2",
            slug: "mod2",
            title: "Mod2",
            description: "desc",
            categories: [],
            projectType: "mod",
            downloads: 500,
            team: "Team2",
            license: nil
        )

        let project = ModrinthProject.from(detail: detail)

        XCTAssertEqual(project.license, "")
    }

    func testModrinthProject_fromDetail_additionalCategories() throws {
        let detail = try makeDetail(
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
        )

        let project = ModrinthProject.from(detail: detail)

        XCTAssertEqual(project.displayCategories, ["library", "utility"])
    }

    // MARK: - Helpers

    private func makeDetail(
        id: String,
        slug: String,
        title: String,
        description: String,
        categories: [String],
        additionalCategories: [String]? = nil,
        projectType: String,
        downloads: Int,
        team: String,
        license: String?
    ) throws -> ModrinthProjectDetail {
        let licenseObj: License? = license.map { License(id: "mit", name: $0, url: nil) }

        return ModrinthProjectDetail(
            slug: slug,
            title: title,
            description: description,
            categories: categories,
            clientSide: "required",
            serverSide: "required",
            body: "",
            additionalCategories: additionalCategories,
            issuesUrl: nil,
            sourceUrl: nil,
            wikiUrl: nil,
            discordUrl: nil,
            projectType: projectType,
            downloads: downloads,
            iconUrl: nil,
            id: id,
            team: team,
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
