//
//  ResourceDetailState.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Observation

/// Aggregates sidebar selection, game/resource type, and project detail state.
///
/// Intended to be provided via `@Environment` to reduce `@Binding` proliferation.
@MainActor
@Observable
public final class ResourceDetailState {
    public var selectedItem: SidebarItem
    public var gameType: Bool // false = local, true = server
    public var gameId: String?
    public var gameResourcesType: String
    public var selectedProjectId: String? {
        didSet {
            if selectedProjectId != oldValue {
                loadedProjectDetail = nil
            }
        }
    }

    public var loadedProjectDetail: ModrinthProjectDetail?
    public var showInstallSheet: Bool = false
    public var currentProject: ModrinthProject?
    var compatibleGames: [GameVersionInfo] = []

    public init(
        selectedItem: SidebarItem = .resource(.mod),
        gameType: Bool = true,
        gameId: String? = nil,
        gameResourcesType: String = ResourceType.mod.rawValue,
        selectedProjectId: String? = nil,
        loadedProjectDetail: ModrinthProjectDetail? = nil,
        loadedProjectDetailV3 _: ModrinthProjectDetailV3? = nil,
    ) {
        self.selectedItem = selectedItem
        self.gameType = gameType
        self.gameId = gameId
        self.gameResourcesType = gameResourcesType
        self.selectedProjectId = selectedProjectId
        self.loadedProjectDetail = loadedProjectDetail
    }

    /// Clears the current project and game selection.
    public func clearSelection() {
        selectedProjectId = nil
        loadedProjectDetail = nil
    }
}
