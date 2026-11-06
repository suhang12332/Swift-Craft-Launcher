//
//  ModDependencyGraphViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import Foundation
import Observation

/// Loads the dependency graph for a game and resolves the icons shown by the
/// custom layered dependency view.
@MainActor
@Observable
final class ModDependencyGraphViewModel {
    enum Phase {
        case idle
        case loading
        case ready(ModDependencyGraphLayout)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var projectIcons: [String: NSImage] = [:]

    private var loadedGameID: String?
    private var loadGeneration = 0

    var isLoading: Bool {
        if case .loading = phase {
            return true
        }
        return false
    }

    var isReady: Bool {
        if case .ready = phase {
            return true
        }
        return false
    }

    func clear() {
        loadGeneration &+= 1
        phase = .idle
        projectIcons = [:]
        loadedGameID = nil
    }

    func load(game: GameVersionInfo, force: Bool = false) async {
        guard force || loadedGameID != game.id || !isReady else {
            return
        }

        loadGeneration &+= 1
        let generation = loadGeneration
        phase = .loading
        projectIcons = [:]

        do {
            let prepared = try await preparePresentation(for: game)
            guard !Task.isCancelled, generation == loadGeneration else {
                return
            }
            let icons = await ModDependencyIconLoader.load(iconURLs: prepared.iconURLs)

            guard !Task.isCancelled, generation == loadGeneration else {
                return
            }

            projectIcons = icons
            loadedGameID = game.id
            phase = .ready(prepared.layout)
        } catch {
            guard !Task.isCancelled, generation == loadGeneration else {
                return
            }
            let globalError = GlobalError.from(error)
            phase = .failed(globalError.localizedDescription)
        }
    }

    /// Builds the lightweight render model and icon URL list in a short-lived
    /// scope so the source graph can be released before image downloads begin.
    private func preparePresentation(
        for game: GameVersionInfo,
    ) async throws -> (layout: ModDependencyGraphLayout, iconURLs: [String: URL]) {
        let (nodes, edges, iconURLs) = try await buildRenderData(for: game)

        // Graph layout is pure CPU work; keep it off the main actor so opening
        // the window does not block the UI while the graph is being arranged.
        let layout = await Task.detached(priority: .userInitiated) {
            ModDependencyGraphLayout(nodes: nodes, edges: edges)
        }.value

        return (layout, iconURLs)
    }

    /// Extracts only the data needed for rendering.
    ///
    /// `ModDependencyGraph` plus all scan/build intermediates live only inside
    /// this scope, so they are released before the layout pass and icon
    /// downloads start.
    private func buildRenderData(
        for game: GameVersionInfo,
    ) async throws -> (
        nodes: [ModDependencyGraph.Node],
        edges: [ModDependencyGraph.Edge],
        iconURLs: [String: URL]
    ) {
        let graph = try await ModDependencyGraphService().buildGraph(for: game)
        return (
            graph.nodes,
            graph.edges,
            ModDependencyIconLoader.iconURLs(for: graph),
        )
    }
}
