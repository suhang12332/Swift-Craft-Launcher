//
//  ModDependencyGraphService.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Scans a game's local mods and builds its dependency graph in one step.
struct ModDependencyGraphService: Sendable {
    static let noModsErrorKey = "mod.dependency_graph.empty.message"

    typealias ExternalProjectProvider = @Sendable (String) async -> ModrinthProjectDetail?

    let scanner: LocalModScanner
    let builder: ModDependencyGraphBuilder
    let externalProjectProvider: ExternalProjectProvider

    init(
        scanner: LocalModScanner = LocalModScanner(),
        builder: ModDependencyGraphBuilder = ModDependencyGraphBuilder(),
        externalProjectProvider: @escaping ExternalProjectProvider = { projectId in
            try? await ModrinthService.fetchProjectDetailsThrowing(id: projectId)
        },
    ) {
        self.scanner = scanner
        self.builder = builder
        self.externalProjectProvider = externalProjectProvider
    }

    /// Scans every mod installed in `game` and returns the dependency graph.
    func buildGraph(for game: GameVersionInfo) async throws -> ModDependencyGraph {
        var localMods = try await scanner.scan(game: game)
        guard !localMods.isEmpty else {
            throw Self.noModsError()
        }

        var missingProjectIds = ModDependencyGraphBuilder.missingDependencyProjectIds(in: localMods)
        var externalProjects = await fetchExternalProjects(ids: missingProjectIds)

        let graph = builder.build(
            ModDependencyGraphBuilder.Input(
                localMods: localMods,
                missingProjectIds: missingProjectIds.sorted(),
                externalProjects: externalProjects,
            ),
        )

        // The flattened graph owns everything the renderer needs. Release the
        // scan results and external project details explicitly instead of
        // keeping them alive until the caller returns.
        localMods.removeAll(keepingCapacity: false)
        missingProjectIds.removeAll(keepingCapacity: false)
        externalProjects.removeAll(keepingCapacity: false)

        return graph
    }

    static func noModsError() -> GlobalError {
        GlobalError.validation(
            i18nKey: noModsErrorKey,
            level: .popup,
        )
        .withTitleKey("mod.dependency_graph.empty.title")
    }

    private func fetchExternalProjects(ids: Set<String>) async -> [String: ModrinthProjectDetail] {
        guard !ids.isEmpty else {
            return [:]
        }

        let semaphore = AsyncSemaphore(value: scanner.maxConcurrentTasks)

        return await withTaskGroup(of: (String, ModrinthProjectDetail?).self) { group in
            for projectId in ids {
                group.addTask {
                    await semaphore.wait()
                    let detail = await externalProjectProvider(projectId)
                    await semaphore.signal()
                    return (projectId, detail)
                }
            }

            var results: [String: ModrinthProjectDetail] = [:]
            results.reserveCapacity(ids.count)
            for await (projectId, detail) in group {
                if let detail {
                    results[projectId] = detail
                }
            }
            return results
        }
    }
}
