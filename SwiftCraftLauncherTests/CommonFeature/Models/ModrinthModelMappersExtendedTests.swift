//
//  ModrinthModelMappersExtendedTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CFModrinthAdapterKit
@testable import SwiftCraftLauncher
import XCTest

final class ModrinthModelMappersExtendedTests: XCTestCase {
    func testFromV3_basicMapping() {
        let v3 = makeV3(
            id: "v3-id",
            slug: "my-project",
            name: "My Project",
            summary: "Short summary",
            description: "Long description",
            projectTypes: ["mod"],
            downloads: 500,
            organization: "MyOrg",
            categories: ["fabric"],
            additionalCategories: ["library"],
            loaders: ["fabric"],
            versions: ["1.20.1", "1.21"],
            gameVersions: ["1.20.1", "1.21"],
        )

        let detail = ModrinthProjectDetail.fromV3(v3)

        XCTAssertEqual(detail.id, "v3-id")
        XCTAssertEqual(detail.slug, "my-project")
        XCTAssertEqual(detail.title, "My Project")
        XCTAssertEqual(detail.description, "Short summary")
        XCTAssertEqual(detail.body, "Long description")
        XCTAssertEqual(detail.projectType, "mod")
        XCTAssertEqual(detail.downloads, 500)
        XCTAssertEqual(detail.team, "MyOrg")
        XCTAssertEqual(detail.categories, ["fabric"])
        XCTAssertEqual(detail.additionalCategories, ["library"])
        XCTAssertEqual(detail.loaders, ["fabric"])
        XCTAssertEqual(detail.clientSide, "required")
        XCTAssertEqual(detail.serverSide, "required")
    }

    func testFromV3_nilOrganization() {
        let v3 = makeV3(
            id: "id",
            slug: "s",
            name: "N",
            summary: "S",
            description: "D",
            projectTypes: ["mod"],
            downloads: 0,
            organization: nil,
            categories: [],
            additionalCategories: [],
            loaders: [],
            versions: [],
            gameVersions: [],
        )

        let detail = ModrinthProjectDetail.fromV3(v3)
        XCTAssertEqual(detail.team, "")
    }

    func testFromV3_emptyProjectTypes() {
        let v3 = makeV3(
            id: "id",
            slug: "s",
            name: "N",
            summary: "S",
            description: "D",
            projectTypes: [],
            downloads: 0,
            organization: nil,
            categories: [],
            additionalCategories: [],
            loaders: [],
            versions: [],
            gameVersions: [],
        )

        let detail = ModrinthProjectDetail.fromV3(v3)
        XCTAssertEqual(detail.projectType, "minecraft_java_server")
    }

    func testFromV3_withLicense() {
        let license = License(id: "mit", name: "MIT", url: nil)
        let v3 = makeV3(
            id: "id",
            slug: "s",
            name: "N",
            summary: "S",
            description: "D",
            projectTypes: ["mod"],
            downloads: 0,
            organization: nil,
            categories: [],
            additionalCategories: [],
            loaders: [],
            versions: [],
            gameVersions: [],
            license: license,
        )

        let detail = ModrinthProjectDetail.fromV3(v3)
        XCTAssertEqual(detail.license?.id, "mit")
        XCTAssertEqual(detail.license?.name, "MIT")
    }

    func testFromV3_gameVersions_deduplication() {
        let v3 = makeV3(
            id: "id",
            slug: "s",
            name: "N",
            summary: "S",
            description: "D",
            projectTypes: ["mod"],
            downloads: 0,
            organization: nil,
            categories: [],
            additionalCategories: [],
            loaders: [],
            versions: [],
            gameVersions: ["1.20.1", "1.21", "1.20.1"],
        )

        let detail = ModrinthProjectDetail.fromV3(v3)
        XCTAssertEqual(detail.gameVersions, ["1.20.1", "1.21"])
    }

    func testFromV3_javaServerInfo_fillsFileName() throws {
        let dict: [String: Any] = [
            "id": "id",
            "slug": "s",
            "project_types": ["minecraft_java_server"],
            "games": ["minecraft"],
            "game_versions": [] as [String],
            "team_id": "team-1",
            "name": "N",
            "summary": "S",
            "description": "D",
            "published": "2023-11-14T22:13:20.000Z",
            "updated": "2023-11-14T22:13:20.000Z",
            "status": "approved",
            "requested_status": "approved",
            "license": ["id": "mit", "name": "MIT"] as [String: Any],
            "downloads": 0,
            "followers": 0,
            "categories": [] as [String],
            "additional_categories": [] as [String],
            "loaders": [] as [String],
            "versions": [] as [String],
            "gallery": [] as [Any],
            "minecraft_java_server": [
                "address": "mc.example.com",
                "ping": [
                    "when": "2023-11-14T22:13:20.000Z",
                    "address": "mc.example.com",
                    "data": [
                        "latency": ["secs": 0, "nanos": 0],
                        "version_name": "1.20.1",
                        "version_protocol": 763,
                        "description": "A Server",
                        "players_online": 10,
                        "players_max": 100,
                    ] as [String: Any],
                ] as [String: Any],
            ] as [String: Any],
        ]
        // swiftlint:disable:next force_try
        let data = try JSONSerialization.data(withJSONObject: dict)
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatter.date(from: dateString) { return date }
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            return fallback.date(from: dateString) ?? Date(timeIntervalSince1970: 0)
        }
        // swiftlint:disable:next force_try
        let v3 = try decoder.decode(ModrinthProjectDetailV3.self, from: data)

        let detail = ModrinthProjectDetail.fromV3(v3)
        XCTAssertNotNil(detail.fileName, "fileName should not be nil")
        XCTAssertTrue(detail.fileName?.contains("mc.example.com") ?? false, "fileName should contain address")
        XCTAssertTrue(detail.fileName?.contains("10 | 100") ?? false, "fileName should contain player counts, got: \(detail.fileName ?? "nil")")
    }

    func testFromV3_javaServerInfo_noPing() {
        let serverInfo = makeJavaServerInfo(
            address: "mc.example.com",
            pingPlayersOnline: nil,
            pingPlayersMax: nil,
        )

        let v3 = makeV3(
            id: "id",
            slug: "s",
            name: "N",
            summary: "S",
            description: "D",
            projectTypes: ["minecraft_java_server"],
            downloads: 0,
            organization: nil,
            categories: [],
            additionalCategories: [],
            loaders: [],
            versions: [],
            gameVersions: [],
            minecraftJavaServer: serverInfo,
        )

        let detail = ModrinthProjectDetail.fromV3(v3)
        XCTAssertEqual(detail.fileName, "mc.example.com")
    }

    func testFromV3_emptyAddress_noFileName() {
        let serverInfo = makeJavaServerInfo(
            address: "",
            pingPlayersOnline: nil,
            pingPlayersMax: nil,
        )

        let v3 = makeV3(
            id: "id",
            slug: "s",
            name: "N",
            summary: "S",
            description: "D",
            projectTypes: ["minecraft_java_server"],
            downloads: 0,
            organization: nil,
            categories: [],
            additionalCategories: [],
            loaders: [],
            versions: [],
            gameVersions: [],
            minecraftJavaServer: serverInfo,
        )

        let detail = ModrinthProjectDetail.fromV3(v3)
        XCTAssertNil(detail.fileName)
    }

    func testFromDetail_displayCategories_nilAdditional() {
        let detail = makeDetail(
            id: "id",
            categories: ["fabric"],
            additionalCategories: nil,
            license: nil,
        )

        let project = ModrinthProject.from(detail: detail)
        XCTAssertTrue(project.displayCategories.isEmpty)
    }

    func testFromDetail_displayCategories_nonNil() {
        let detail = makeDetail(
            id: "id",
            categories: ["fabric"],
            additionalCategories: ["library", "utility"],
            license: nil,
        )

        let project = ModrinthProject.from(detail: detail)
        XCTAssertEqual(project.displayCategories, ["library", "utility"])
    }

    func testFromDetail_fileName() {
        let detail = makeDetail(
            id: "id",
            categories: [],
            additionalCategories: nil,
            license: nil,
            fileName: "mod-1.0.jar",
        )

        let project = ModrinthProject.from(detail: detail)
        XCTAssertEqual(project.fileName, "mod-1.0.jar")
    }

    func testFromDetail_fileName_nil() {
        let detail = makeDetail(
            id: "id",
            categories: [],
            additionalCategories: nil,
            license: nil,
            fileName: nil,
        )

        let project = ModrinthProject.from(detail: detail)
        XCTAssertNil(project.fileName)
    }

    // swiftlint:disable:next function_parameter_count
    private func makeV3(
        id: String,
        slug: String,
        name: String,
        summary: String,
        description: String,
        projectTypes: [String],
        downloads: Int,
        organization: String?,
        categories: [String],
        additionalCategories: [String],
        loaders: [String],
        versions: [String],
        gameVersions: [String],
        license: License = License(id: "mit", name: "MIT", url: nil),
        minecraftJavaServer: ModrinthMinecraftJavaServerInfo? = nil,
    ) -> ModrinthProjectDetailV3 {
        var dict: [String: Any] = [
            "id": id,
            "slug": slug,
            "project_types": projectTypes,
            "games": ["minecraft"],
            "game_versions": gameVersions,
            "team_id": "team-1",
            "name": name,
            "summary": summary,
            "description": description,
            "published": "2023-11-14T22:13:20.000Z",
            "updated": "2023-11-14T22:13:20.000Z",
            "status": "approved",
            "requested_status": "approved",
            "license": ["id": license.id, "name": license.name] as [String: Any],
            "downloads": downloads,
            "followers": 0,
            "categories": categories,
            "additional_categories": additionalCategories,
            "loaders": loaders,
            "versions": versions,
            "gallery": [],
        ]
        if let organization {
            dict["organization"] = organization
        }
        if let serverInfo = minecraftJavaServer {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(serverInfo),
               let jsonObj = try? JSONSerialization.jsonObject(with: data) {
                dict["minecraft_java_server"] = jsonObj
            }
        }
        // swiftlint:disable:next force_try
        let data = try! JSONSerialization.data(withJSONObject: dict)
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatter.date(from: dateString) { return date }
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            return fallback.date(from: dateString) ?? Date(timeIntervalSince1970: 0)
        }
        // swiftlint:disable:next force_try
        return try! decoder.decode(ModrinthProjectDetailV3.self, from: data)
    }

    private func makeDetail(
        id: String,
        categories: [String],
        additionalCategories: [String]?,
        license: License?,
        fileName: String? = nil,
    ) -> ModrinthProjectDetail {
        ModrinthProjectDetail(
            slug: "slug",
            title: "Title",
            description: "Description",
            categories: categories,
            clientSide: "required",
            serverSide: "required",
            body: "",
            additionalCategories: additionalCategories,
            issuesUrl: nil,
            sourceUrl: nil,
            wikiUrl: nil,
            discordUrl: nil,
            projectType: "mod",
            downloads: 0,
            iconUrl: nil,
            id: id,
            team: "team",
            published: Date(timeIntervalSince1970: 1_700_000_000),
            updated: Date(timeIntervalSince1970: 1_700_000_000),
            followers: 0,
            license: license,
            versions: [],
            gameVersions: [],
            loaders: [],
            type: nil,
            fileName: fileName,
        )
    }

    private func makeJavaServerInfo(
        address: String,
        pingPlayersOnline: Int?,
        pingPlayersMax: Int?,
    ) -> ModrinthMinecraftJavaServerInfo {
        var dict: [String: Any] = ["address": address]
        if let online = pingPlayersOnline, let max = pingPlayersMax {
            dict["ping"] = [
                "when": "2023-11-14T22:13:20.000Z",
                "address": address,
                "data": [
                    "latency": ["secs": 0, "nanos": 0],
                    "version_name": "1.20.1",
                    "version_protocol": 763,
                    "description": "A Server",
                    "players_online": online,
                    "players_max": max,
                ] as [String: Any],
            ] as [String: Any]
        }
        // swiftlint:disable:next force_try
        let data = try! JSONSerialization.data(withJSONObject: dict)
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatter.date(from: dateString) { return date }
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            return fallback.date(from: dateString) ?? Date(timeIntervalSince1970: 0)
        }
        // swiftlint:disable:next force_try
        return try! decoder.decode(ModrinthMinecraftJavaServerInfo.self, from: data)
    }
}
