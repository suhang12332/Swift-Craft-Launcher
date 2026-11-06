//
//  ModDependencyGraphBuilderTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class ModDependencyGraphBuilderTests: XCTestCase {
    private let builder = ModDependencyGraphBuilder()

    private func makeInput(
        localMods: [LocalMod],
        externalProjects: [String: ModrinthProjectDetail] = [:],
    ) -> ModDependencyGraphBuilder.Input {
        ModDependencyGraphBuilder.Input(
            localMods: localMods,
            missingProjectIds: ModDependencyGraphBuilder
                .missingDependencyProjectIds(in: localMods)
                .sorted(),
            externalProjects: externalProjects,
        )
    }

    private func makeLayout(_ graph: ModDependencyGraph) -> ModDependencyGraphLayout {
        ModDependencyGraphLayout(nodes: graph.nodes, edges: graph.edges)
    }

    // MARK: - Graph shape

    func testBuild_withNoModsReturnsEmptyGraph() {
        let graph = builder.build(makeInput(localMods: []))

        XCTAssertTrue(graph.nodes.isEmpty)
        XCTAssertTrue(graph.edges.isEmpty)
    }

    func testBuild_buildsEdgeForRequiredLocalDependency() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "B Library")

        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(
                projectId: projectA.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [
                    Self.dependency(projectB.id, type: "required"),
                    Self.dependency("project-optional", type: "optional"),
                    Self.dependency("project-embedded", type: "embedded"),
                ],
            ),
        )
        let modB = Self.makeLocalMod(
            project: projectB,
            version: Self.makeVersion(projectId: projectB.id, versionId: "b-1", sha1: "hash-b"),
        )

        let graph = builder.build(makeInput(localMods: [modA, modB]))
        let aID = projectA.id
        let bID = projectB.id
        let nodeB = graph.nodes.first { $0.projectId == projectB.id }

        XCTAssertEqual(graph.nodes.count, 2)
        XCTAssertEqual(graph.edges.count, 1)
        XCTAssertEqual(graph.edges.first?.from, aID)
        XCTAssertEqual(graph.edges.first?.to, bID)
        XCTAssertEqual(nodeB?.fileName, "project-b.jar")
        XCTAssertEqual(nodeB?.isInstalled, true)
    }

    func testBuild_ignoresOptionalAndEmbeddedDependencies() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(
                projectId: projectA.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [
                    Self.dependency("project-optional", type: "optional"),
                    Self.dependency("project-embedded", type: "embedded"),
                    Self.dependency("project-incompatible", type: "incompatible"),
                ],
            ),
        )

        let graph = builder.build(makeInput(localMods: [modA]))

        XCTAssertEqual(graph.nodes.count, 1)
        XCTAssertTrue(graph.edges.isEmpty)
    }

    func testBuild_missingDependencyUsesExternalDetail() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "Remote Library")
        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(
                projectId: projectA.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [Self.dependency(projectB.id, type: "required")],
            ),
        )

        let graph = builder.build(makeInput(
            localMods: [modA],
            externalProjects: [projectB.id: projectB],
        ))
        let nodeB = graph.nodes.first { $0.projectId == projectB.id }

        XCTAssertEqual(nodeB?.title, "Remote Library")
        XCTAssertEqual(nodeB?.isInstalled, false)
        XCTAssertNil(nodeB?.fileName)
    }

    func testBuild_missingDependencyWithoutDetailUsesPlaceholder() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(
                projectId: projectA.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [Self.dependency("project-missing", type: "required")],
            ),
        )

        let graph = builder.build(makeInput(localMods: [modA]))
        let node = graph.nodes.first { $0.projectId == "project-missing" }

        XCTAssertEqual(node?.title, "project-missing")
        XCTAssertEqual(node?.isInstalled, false)
    }

    func testBuild_sharedDependencyIsStoredOnce() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "B Mod")
        let shared = Self.makeDetail(id: "project-shared", title: "Shared Library")

        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(
                projectId: projectA.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [Self.dependency(shared.id, type: "required")],
            ),
        )
        let modB = Self.makeLocalMod(
            project: projectB,
            version: Self.makeVersion(
                projectId: projectB.id,
                versionId: "b-1",
                sha1: "hash-b",
                dependencies: [Self.dependency(shared.id, type: "required")],
            ),
        )
        let sharedMod = Self.makeLocalMod(
            project: shared,
            version: Self.makeVersion(projectId: shared.id, versionId: "shared-1", sha1: "hash-shared"),
        )

        let graph = builder.build(makeInput(
            localMods: [modA, modB, sharedMod],
        ))
        let sharedID = shared.id

        XCTAssertEqual(graph.nodes.count, 3)
        XCTAssertEqual(graph.nodes.filter { $0.projectId == shared.id }.count, 1)
        XCTAssertEqual(graph.edges.count, 2)
        XCTAssertEqual(graph.edges.filter { $0.to == sharedID }.count, 2)
    }

    func testBuild_detectsDependencyCycle() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "B Mod")

        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(
                projectId: projectA.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [Self.dependency(projectB.id, type: "required")],
            ),
        )
        let modB = Self.makeLocalMod(
            project: projectB,
            version: Self.makeVersion(
                projectId: projectB.id,
                versionId: "b-1",
                sha1: "hash-b",
                dependencies: [Self.dependency(projectA.id, type: "required")],
            ),
        )

        let graph = builder.build(makeInput(localMods: [modA, modB]))

        XCTAssertEqual(graph.nodes.count, 2)
        XCTAssertEqual(graph.edges.count, 2)
        XCTAssertTrue(graph.nodes.allSatisfy(\.isCycle))
    }

    func testBuild_prefersEnabledFileWhenProjectIsInstalledTwice() {
        let project = Self.makeDetail(id: "project-a", title: "A Mod")
        let enabled = Self.makeLocalMod(
            project: project,
            version: Self.makeVersion(projectId: project.id, versionId: "a-1", sha1: "hash-a"),
            fileName: "a.jar",
            isEnabled: true,
        )
        let disabled = Self.makeLocalMod(
            project: project,
            version: Self.makeVersion(projectId: project.id, versionId: "a-1", sha1: "hash-a"),
            fileName: "a.jar.disable",
            isEnabled: false,
        )

        let graph = builder.build(makeInput(localMods: [disabled, enabled]))

        XCTAssertEqual(graph.nodes.count, 1)
        XCTAssertEqual(graph.nodes.first?.fileName, "a.jar")
        XCTAssertEqual(graph.nodes.first?.isEnabled, true)
    }

    func testBuild_duplicateEnabledFilesUseStableOrder() {
        let project = Self.makeDetail(id: "project-a", title: "A Mod")
        let fileB = Self.makeLocalMod(
            project: project,
            version: Self.makeVersion(
                projectId: project.id,
                versionId: "a-2",
                sha1: "hash-b",
                dependencies: [Self.dependency("project-b", type: "required")],
            ),
            fileName: "b.jar",
            isEnabled: true,
        )
        let fileA = Self.makeLocalMod(
            project: project,
            version: Self.makeVersion(
                projectId: project.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [Self.dependency("project-a-dep", type: "required")],
            ),
            fileName: "a.jar",
            isEnabled: true,
        )

        let firstGraph = builder.build(makeInput(localMods: [fileB, fileA]))
        let secondGraph = builder.build(makeInput(localMods: [fileA, fileB]))
        let firstEdges = firstGraph.edges.map { "\($0.from)->\($0.to)" }
        let secondEdges = secondGraph.edges.map { "\($0.from)->\($0.to)" }

        XCTAssertEqual(firstGraph.nodes.first { $0.projectId == project.id }?.fileName, "a.jar")
        XCTAssertEqual(firstEdges, secondEdges)
        XCTAssertEqual(firstEdges, ["project-a->project-a-dep"])
    }

    func testBuild_carriesDisabledState() {
        let project = Self.makeDetail(id: "project-a", title: "A Mod")
        let mod = Self.makeLocalMod(
            project: project,
            version: Self.makeVersion(projectId: project.id, versionId: "a-1", sha1: "hash-a"),
            fileName: "a.jar.disable",
            isEnabled: false,
        )

        let graph = builder.build(makeInput(localMods: [mod]))

        XCTAssertEqual(graph.nodes.first?.isEnabled, false)
    }

    // MARK: - Layout

    func testLayout_connectsRequiredProjectToItsDependent() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "B Library")
        let projectC = Self.makeDetail(id: "project-c", title: "C Core")

        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(
                projectId: projectA.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [Self.dependency(projectB.id, type: "required")],
            ),
        )
        let modB = Self.makeLocalMod(
            project: projectB,
            version: Self.makeVersion(
                projectId: projectB.id,
                versionId: "b-1",
                sha1: "hash-b",
                dependencies: [Self.dependency(projectC.id, type: "required")],
            ),
        )
        let modC = Self.makeLocalMod(
            project: projectC,
            version: Self.makeVersion(projectId: projectC.id, versionId: "c-1", sha1: "hash-c"),
        )

        let graph = builder.build(makeInput(localMods: [modA, modB, modC]))
        let layout = makeLayout(graph)
        let rootTargets = Set(layout.edges
            .filter { $0.from == ModDependencyGraphLayout.gameNodeID }
            .map(\.to))

        XCTAssertEqual(rootTargets, [projectC.id])
        XCTAssertTrue(layout.edges.contains {
            $0.from == projectC.id
                && $0.to == projectB.id
        })
        XCTAssertTrue(layout.edges.contains {
            $0.from == projectB.id
                && $0.to == projectA.id
        })
        XCTAssertEqual(layout.edges.count, 3)
    }

    func testLayout_removesTransitiveDependencyEdges() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "B Library")
        let projectC = Self.makeDetail(id: "project-c", title: "C Core")

        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(
                projectId: projectA.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [
                    Self.dependency(projectB.id, type: "required"),
                    Self.dependency(projectC.id, type: "required"),
                ],
            ),
        )
        let modB = Self.makeLocalMod(
            project: projectB,
            version: Self.makeVersion(
                projectId: projectB.id,
                versionId: "b-1",
                sha1: "hash-b",
                dependencies: [Self.dependency(projectC.id, type: "required")],
            ),
        )
        let modC = Self.makeLocalMod(
            project: projectC,
            version: Self.makeVersion(projectId: projectC.id, versionId: "c-1", sha1: "hash-c"),
        )

        let graph = builder.build(makeInput(localMods: [modA, modB, modC]))
        let layout = makeLayout(graph)
        let rootTargets = Set(layout.edges
            .filter { $0.from == ModDependencyGraphLayout.gameNodeID }
            .map(\.to))
        let cID = projectC.id
        let bID = projectB.id
        let aID = projectA.id

        XCTAssertEqual(rootTargets, [cID])
        XCTAssertFalse(layout.edges.contains { $0.from == cID && $0.to == aID })
        XCTAssertTrue(layout.edges.contains { $0.from == cID && $0.to == bID })
        XCTAssertTrue(layout.edges.contains { $0.from == bID && $0.to == aID })
    }

    func testLayout_sharedDependencyFansOutToDependents() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "B Mod")
        let shared = Self.makeDetail(id: "project-shared", title: "Shared Library")

        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(
                projectId: projectA.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [Self.dependency(shared.id, type: "required")],
            ),
        )
        let modB = Self.makeLocalMod(
            project: projectB,
            version: Self.makeVersion(
                projectId: projectB.id,
                versionId: "b-1",
                sha1: "hash-b",
                dependencies: [Self.dependency(shared.id, type: "required")],
            ),
        )
        let sharedMod = Self.makeLocalMod(
            project: shared,
            version: Self.makeVersion(projectId: shared.id, versionId: "shared-1", sha1: "hash-shared"),
        )

        let graph = builder.build(makeInput(
            localMods: [modA, modB, sharedMod],
        ))
        let layout = makeLayout(graph)
        let rootTargets = Set(layout.edges
            .filter { $0.from == ModDependencyGraphLayout.gameNodeID }
            .map(\.to))

        XCTAssertEqual(rootTargets, [shared.id])
        XCTAssertTrue(layout.edges.contains {
            $0.from == shared.id
                && $0.to == projectA.id
        })
        XCTAssertTrue(layout.edges.contains {
            $0.from == shared.id
                && $0.to == projectB.id
        })
    }

    func testLayout_pureCycleStillConnectsGameRoot() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "B Mod")

        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(
                projectId: projectA.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [Self.dependency(projectB.id, type: "required")],
            ),
        )
        let modB = Self.makeLocalMod(
            project: projectB,
            version: Self.makeVersion(
                projectId: projectB.id,
                versionId: "b-1",
                sha1: "hash-b",
                dependencies: [Self.dependency(projectA.id, type: "required")],
            ),
        )

        let graph = builder.build(makeInput(localMods: [modA, modB]))
        let layout = makeLayout(graph)
        let rootTargets = layout.edges
            .filter { $0.from == ModDependencyGraphLayout.gameNodeID }
            .map(\.to)

        XCTAssertEqual(rootTargets.count, 1)
        XCTAssertTrue([projectA.id, projectB.id].contains(rootTargets[0]))
    }

    func testLayout_keepsDependencyEdgesWhenCycleHasShortcut() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "B Mod")
        let projectC = Self.makeDetail(id: "project-c", title: "C Library")

        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(
                projectId: projectA.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [
                    Self.dependency(projectB.id, type: "required"),
                    Self.dependency(projectC.id, type: "required"),
                ],
            ),
        )
        let modB = Self.makeLocalMod(
            project: projectB,
            version: Self.makeVersion(
                projectId: projectB.id,
                versionId: "b-1",
                sha1: "hash-b",
                dependencies: [
                    Self.dependency(projectA.id, type: "required"),
                    Self.dependency(projectC.id, type: "required"),
                ],
            ),
        )
        let modC = Self.makeLocalMod(
            project: projectC,
            version: Self.makeVersion(projectId: projectC.id, versionId: "c-1", sha1: "hash-c"),
        )

        let graph = builder.build(makeInput(localMods: [modA, modB, modC]))
        let layout = makeLayout(graph)

        XCTAssertTrue(layout.edges.contains { $0.from == projectC.id && $0.to == projectA.id })
        XCTAssertTrue(layout.edges.contains { $0.from == projectC.id && $0.to == projectB.id })
        XCTAssertTrue(layout.edges.contains { $0.from == projectB.id && $0.to == projectA.id })
        XCTAssertTrue(layout.edges.contains { $0.from == projectA.id && $0.to == projectB.id })
    }

    func testLayout_connectsEveryCycleOnlyComponentToGameRoot() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "B Mod")
        let projectC = Self.makeDetail(id: "project-c", title: "C Mod")
        let projectD = Self.makeDetail(id: "project-d", title: "D Mod")
        let projectE = Self.makeDetail(id: "project-e", title: "E Mod")

        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(projectId: projectA.id, versionId: "a-1", sha1: "hash-a"),
        )
        let modB = Self.makeLocalMod(
            project: projectB,
            version: Self.makeVersion(
                projectId: projectB.id,
                versionId: "b-1",
                sha1: "hash-b",
                dependencies: [Self.dependency(projectC.id, type: "required")],
            ),
        )
        let modC = Self.makeLocalMod(
            project: projectC,
            version: Self.makeVersion(
                projectId: projectC.id,
                versionId: "c-1",
                sha1: "hash-c",
                dependencies: [Self.dependency(projectB.id, type: "required")],
            ),
        )
        let modD = Self.makeLocalMod(
            project: projectD,
            version: Self.makeVersion(
                projectId: projectD.id,
                versionId: "d-1",
                sha1: "hash-d",
                dependencies: [Self.dependency(projectE.id, type: "required")],
            ),
        )
        let modE = Self.makeLocalMod(
            project: projectE,
            version: Self.makeVersion(
                projectId: projectE.id,
                versionId: "e-1",
                sha1: "hash-e",
                dependencies: [Self.dependency(projectD.id, type: "required")],
            ),
        )

        let graph = builder.build(makeInput(localMods: [modA, modB, modC, modD, modE]))
        let layout = makeLayout(graph)
        let rootTargets = Set(layout.edges
            .filter { $0.from == ModDependencyGraphLayout.gameNodeID }
            .map(\.to))

        XCTAssertEqual(rootTargets.count, 3)
        XCTAssertTrue(rootTargets.contains(projectA.id))
        XCTAssertEqual(rootTargets.intersection([projectB.id, projectC.id]).count, 1)
        XCTAssertEqual(rootTargets.intersection([projectD.id, projectE.id]).count, 1)
    }

    // MARK: - Version matching

    func testInstalledVersionMatchingPrefersPrimaryFile() {
        let primary = Self.makeVersion(projectId: "project-a", versionId: "primary", sha1: "HASH-A")
        let secondary = Self.makeVersion(
            projectId: "project-a",
            versionId: "secondary",
            sha1: "hash-a",
            primary: false,
        )

        let match = ModDependencyGraphBuilder.installedVersion(
            matching: "hash-a",
            in: [secondary, primary],
        )

        XCTAssertEqual(match?.id, "primary")
    }

    func testInstalledVersionMatchingFallsBackToAnyFile() {
        let version = Self.makeVersion(
            projectId: "project-a",
            versionId: "a-1",
            sha1: "hash-a",
            primary: false,
        )

        let match = ModDependencyGraphBuilder.installedVersion(matching: "HASH-A", in: [version])

        XCTAssertEqual(match?.id, "a-1")
    }

    // MARK: - Scanner

    func testScannerResolvesVersionAndEnabledState() async throws {
        let fileEnabled = URL(fileURLWithPath: "/tmp/mods/alpha.jar")
        let fileDisabled = URL(fileURLWithPath: "/tmp/mods/beta.jar.disable")

        let scanner = LocalModScanner(
            fileLister: { _ in [fileEnabled, fileDisabled] },
            detailProvider: { url in
                let id = url.lastPathComponent.hasPrefix("alpha") ? "project-alpha" : "project-beta"
                let hash = url.lastPathComponent.hasPrefix("alpha") ? "hash-alpha" : "hash-beta"
                return (Self.makeDetail(id: id, title: id), hash)
            },
            versionsProvider: { projectId in
                let hash = projectId == "project-alpha" ? "hash-alpha" : "hash-beta"
                return [Self.makeVersion(projectId: projectId, versionId: "\(projectId)-1", sha1: hash)]
            },
            maxConcurrentTasks: 2,
        )

        let mods = try await scanner.scan(game: Self.makeGame())
        let byName = Dictionary(uniqueKeysWithValues: mods.map { ($0.fileName, $0) })

        XCTAssertEqual(byName["alpha.jar"]?.projectId, "project-alpha")
        XCTAssertEqual(byName["alpha.jar"]?.isEnabled, true)
        XCTAssertEqual(byName["beta.jar.disable"]?.projectId, "project-beta")
        XCTAssertEqual(byName["beta.jar.disable"]?.isEnabled, false)
    }

    // MARK: - Service

    func testServiceScansAndFetchesMissingDependencies() async throws {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "Remote Library")

        let scanner = LocalModScanner(
            fileLister: { _ in [URL(fileURLWithPath: "/tmp/mods/a.jar")] },
            detailProvider: { _ in (projectA, "hash-a") },
            versionsProvider: { _ in
                [
                    Self.makeVersion(
                        projectId: projectA.id,
                        versionId: "a-1",
                        sha1: "hash-a",
                        dependencies: [Self.dependency(projectB.id, type: "required")],
                    ),
                ]
            },
            maxConcurrentTasks: 2,
        )
        let service = ModDependencyGraphService(scanner: scanner) { projectId in
            projectId == projectB.id ? projectB : nil
        }

        let graph = try await service.buildGraph(for: Self.makeGame())
        let nodeA = graph.nodes.first { $0.projectId == projectA.id }
        let nodeB = graph.nodes.first { $0.projectId == projectB.id }

        XCTAssertEqual(graph.nodes.count, 2)
        XCTAssertEqual(graph.edges.count, 1)
        XCTAssertEqual(nodeA?.fileName, "a.jar")
        XCTAssertEqual(nodeB?.isInstalled, false)
    }

    // MARK: - Helpers

    private static func makeGame() -> GameVersionInfo {
        GameVersionInfo(
            id: "game-id",
            gameName: "Test Game",
            gameIcon: "",
            gameVersion: "1.20.1",
            assetIndex: "5",
            modLoader: "fabric",
        )
    }

    private static func makeDetail(id: String, title: String) -> ModrinthProjectDetail {
        ModrinthProjectDetail(
            slug: id,
            title: title,
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
            projectType: ResourceType.mod.rawValue,
            downloads: 0,
            iconUrl: nil,
            id: id,
            team: "team-\(id)",
            published: Date(timeIntervalSince1970: 0),
            updated: Date(timeIntervalSince1970: 0),
            followers: 0,
            license: nil,
            versions: [],
            gameVersions: ["1.20.1"],
            loaders: ["fabric"],
            type: ResourceType.mod.rawValue,
            fileName: nil,
        )
    }

    private static func makeVersion(
        projectId: String,
        versionId: String,
        sha1: String,
        dependencies: [ModrinthVersionDependency] = [],
        primary: Bool = true,
    ) -> ModrinthProjectDetailVersion {
        ModrinthProjectDetailVersion(
            gameVersions: ["1.20.1"],
            loaders: ["fabric"],
            id: versionId,
            projectId: projectId,
            authorId: "author",
            featured: false,
            name: versionId,
            versionNumber: versionId,
            changelog: nil,
            changelogUrl: nil,
            datePublished: Date(timeIntervalSince1970: 0),
            downloads: 0,
            versionType: "release",
            status: "listed",
            requestedStatus: nil,
            files: [
                ModrinthVersionFile(
                    hashes: ModrinthVersionFileHashes(sha512: "", sha1: sha1),
                    url: "https://example.com/\(versionId).jar",
                    filename: "\(versionId).jar",
                    primary: primary,
                    size: 0,
                    fileType: nil,
                ),
            ],
            dependencies: dependencies,
        )
    }

    private static func makeLocalMod(
        project: ModrinthProjectDetail,
        version: ModrinthProjectDetailVersion?,
        fileName: String? = nil,
        isEnabled: Bool = true,
    ) -> LocalMod {
        return LocalMod(
            project: project,
            installedVersion: version,
            fileName: fileName ?? "\(project.id).jar",
            isEnabled: isEnabled,
        )
    }

    private static func dependency(_ projectId: String, type: String) -> ModrinthVersionDependency {
        ModrinthVersionDependency(projectId: projectId, versionId: nil, dependencyType: type)
    }
}
