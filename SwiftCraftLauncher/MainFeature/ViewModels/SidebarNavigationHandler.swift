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
    /// - Parameters:
    ///   - oldValue: The previously selected sidebar item.
    ///   - newValue: The newly selected sidebar item.
    func handleSidebarItemChange(from oldValue: SidebarItem, to newValue: SidebarItem) {
        switch (oldValue, newValue) {
        case let (.resource, .game(id)):
            handleResourceToGameTransition(gameId: id)
        case (.game, .resource):
            resetToResourceDefaults()
        case let (.game(oldId), .game(newId)):
            handleGameToGameTransition(from: oldId, to: newId)
        case (.resource, .resource):
            resetToResourceDefaults()
        }
    }

    /// Handles transition from resource view to game view.
    /// - Parameter gameId: The game ID being transitioned to.
    func handleResourceToGameTransition(gameId: String) {
        if detailState.gameId != nil, detailState.selectedProjectId == nil {
            filterState.clearSearchText()
        }
        if detailState.gameType == true, detailState.gameId == nil {
            filterState.clearSearchText()
            detailState.gameType = false
        }

        let game = gameRepository.getGame(by: gameId)
        if let loader = game?.modLoader.lowercased() {
            let currentType = detailState.gameResourcesType.lowercased()
            if loader == GameLoader.vanilla.displayName {
                let modifiableTypes: [String] = [
                    ResourceType.mod.rawValue,
                    ResourceType.shader.rawValue,
                    ResourceType.modpack.rawValue,
                    ResourceType.minecraftJavaServer.rawValue,
                ]
                if modifiableTypes.contains(currentType) {
                    detailState.gameResourcesType = ResourceType.datapack.rawValue
                }
            } else {
                if detailState.selectedProjectId == nil {
                    detailState.gameResourcesType = ResourceType.mod.rawValue
                }
                if detailState.selectedProjectId != nil, detailState.gameResourcesType == ResourceType.minecraftJavaServer.rawValue {
                    detailState.gameResourcesType = ResourceType.mod.rawValue
                }
                if gameId != detailState.gameId {
                    detailState.gameResourcesType = ResourceType.mod.rawValue
                    detailState.gameType = false
                }
            }
        }

        detailState.gameId = gameId
        detailState.selectedProjectId = nil
        container.core.selectedGameManager.setSelectedGame(gameId)
    }

    /// Handles transition between different game views.
    /// - Parameters:
    ///   - from: The previous game ID.
    ///   - to: The new game ID.
    func handleGameToGameTransition(from _: String, to newId: String) {
        filterState.clearSearchText()
        detailState.gameType = false

        let game = gameRepository.getGame(by: newId)
        if let loader = game?.modLoader.lowercased() {
            detailState.gameResourcesType = (loader == GameLoader.vanilla.displayName) ? ResourceType.datapack.rawValue : ResourceType.mod.rawValue
        }
        detailState.gameId = newId
        container.core.selectedGameManager.setSelectedGame(newId)
    }

    /// Resets all state to resource view defaults.
    func resetToResourceDefaults() {
        if case .resource = detailState.selectedItem {
            if detailState.gameId == nil {
                filterState.clearSearchText()
            }
        }
        container.core.selectedGameManager.clearSelection()

        if !detailState.gameType, detailState.selectedProjectId == nil {
            detailState.gameType = true
        }
        filterState.sortIndex = AppConstants.modrinthIndex

        if case let .resource(resourceType) = detailState.selectedItem {
            detailState.gameResourcesType = resourceType.rawValue
        }
        filterState.clearFiltersAndPagination()

        if detailState.gameId == nil, detailState.selectedProjectId != nil {
            detailState.selectedProjectId = nil
        }
        if detailState.selectedProjectId == nil, detailState.gameId != nil {
            detailState.gameId = nil
            filterState.clearSearchText()
        }
        if detailState.loadedProjectDetail != nil, detailState.gameId != nil,
           detailState.selectedProjectId != nil {
            detailState.gameId = nil
            detailState.loadedProjectDetail = nil
            detailState.selectedProjectId = nil
        }
        if !detailState.gameType, detailState.selectedProjectId == nil {
            detailState.gameType = true
        }
        if detailState.gameResourcesType == ResourceType.minecraftJavaServer.rawValue {
            filterState.dataSource = .modrinth
        }
    }
}
