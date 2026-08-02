//
//  SidebarNavigationHandler.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Handles sidebar navigation state transitions and coordinate changes between resource and game views.
@MainActor
@Observable
final class SidebarNavigationHandler {
    private let filterState: ResourceFilterState
    private let detailState: ResourceDetailState
    private let gameRepository: GameRepository
    private let container: DIContainer

    init(
        filterState: ResourceFilterState,
        detailState: ResourceDetailState,
        gameRepository: GameRepository,
        container: DIContainer,
    ) {
        self.filterState = filterState
        self.detailState = detailState
        self.gameRepository = gameRepository
        self.container = container
    }

    /// Handles sidebar item changes and dispatches to appropriate transition handlers.
    func handleSidebarItemChange(from oldValue: SidebarItem, to newValue: SidebarItem) {
        switch (oldValue, newValue) {
        case let (.resource, .game(id)):
            handleResourceToGameTransition(gameId: id)
        case (.game, .resource), (.resource, .resource):
            resetToResourceDefaults()
        case let (.game(oldId), .game(newId)):
            handleGameToGameTransition(from: oldId, to: newId)
        }
    }

    private func handleResourceToGameTransition(gameId: String) {
        if detailState.gameId != nil, detailState.selectedProjectId == nil {
            filterState.clearSearchText()
        }
        if detailState.gameType, detailState.gameId == nil {
            filterState.clearSearchText()
            detailState.gameType = false
        }

        let game = gameRepository.getGame(by: gameId)
        if let loader = game?.modLoader.lowercased() {
            if loader == GameLoader.vanilla.displayName {
                if isUnsupportedForVanilla(detailState.gameResourcesType) {
                    detailState.gameResourcesType = ResourceType.datapack.rawValue
                }
            } else if detailState.selectedProjectId == nil
                || detailState.gameResourcesType == ResourceType.minecraftJavaServer.rawValue
                || gameId != detailState.gameId {
                detailState.gameResourcesType = ResourceType.mod.rawValue
                if gameId != detailState.gameId {
                    detailState.gameType = false
                }
            }
        }

        detailState.gameId = gameId
        detailState.selectedProjectId = nil
        container.core.selectedGameManager.setSelectedGame(gameId)
    }

    private func handleGameToGameTransition(from _: String, to newId: String) {
        filterState.clearSearchText()
        detailState.gameType = false

        let game = gameRepository.getGame(by: newId)
        if let loader = game?.modLoader.lowercased() {
            detailState.gameResourcesType = defaultResourceType(for: loader)
        }
        detailState.gameId = newId
        container.core.selectedGameManager.setSelectedGame(newId)
    }

    private func resetToResourceDefaults() {
        container.core.selectedGameManager.clearSelection()

        if case let .resource(resourceType) = detailState.selectedItem {
            detailState.gameResourcesType = resourceType.rawValue
        }

        cleanupGameRelatedState()

        filterState.sortIndex = AppConstants.modrinthIndex
        filterState.clearFiltersAndPagination()

        if !detailState.gameType, detailState.selectedProjectId == nil {
            detailState.gameType = true
        }

        if detailState.gameResourcesType == ResourceType.minecraftJavaServer.rawValue {
            filterState.dataSource = .modrinth
        }
    }

    private func isUnsupportedForVanilla(_ type: String) -> Bool {
        let unsupported: [String] = [
            ResourceType.mod.rawValue,
            ResourceType.shader.rawValue,
            ResourceType.modpack.rawValue,
            ResourceType.minecraftJavaServer.rawValue,
        ]
        return unsupported.contains(type.lowercased())
    }

    /// Returns the default resource type for the given mod loader.
    private func defaultResourceType(for modLoader: String) -> String {
        modLoader == GameLoader.vanilla.displayName
            ? ResourceType.datapack.rawValue
            : ResourceType.mod.rawValue
    }

    /// Cleans up all game-related state to ensure consistency.
    private func cleanupGameRelatedState() {
        let hasGameId = detailState.gameId != nil
        let hasProjectId = detailState.selectedProjectId != nil
        let hasProjectDetail = detailState.loadedProjectDetail != nil

        if hasProjectDetail, hasGameId, hasProjectId {
            detailState.gameId = nil
            detailState.loadedProjectDetail = nil
            detailState.selectedProjectId = nil
            filterState.clearSearchText()
            return
        }

        if hasGameId, !hasProjectId {
            detailState.gameId = nil
            filterState.clearSearchText()
            return
        }

        if hasProjectId, !hasGameId {
            detailState.selectedProjectId = nil
        }
    }
}
