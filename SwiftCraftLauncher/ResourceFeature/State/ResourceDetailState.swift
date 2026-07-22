//
//  ResourceDetailState.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Observation
import SwiftUI

/// Aggregates sidebar selection, game/resource type, and project detail state.
///
/// Intended to be provided via `@Environment` to reduce `@Binding` proliferation.
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

    /// Selects a game by its identifier.
    public func selectGame(id: String?) {
        gameId = id
    }

    /// Selects a resource type.
    public func selectResource(type: String) {
        gameResourcesType = type
    }

    /// Clears the current project and game selection.
    public func clearSelection() {
        selectedProjectId = nil
        loadedProjectDetail = nil
    }

    private func bind<V>(_ keyPath: WritableKeyPath<ResourceDetailState, V>, fallback: V) -> Binding<V> {
        Binding(
            get: { [weak self] in self?[keyPath: keyPath] ?? fallback },
            set: { [weak self] in self?[keyPath: keyPath] = $0 },
        )
    }

    public var selectedItemBinding: Binding<SidebarItem> { bind(\.selectedItem, fallback: .resource(.mod)) }

    /// Returns a binding suitable for APIs that require an optional selection (e.g. `List(selection:)`).
    public var selectedItemOptionalBinding: Binding<SidebarItem?> {
        Binding(
            get: { [weak self] in self?.selectedItem },
            set: { [weak self] value in
                if let value { self?[keyPath: \.selectedItem] = value }
            },
        )
    }

    public var gameTypeBinding: Binding<Bool> { bind(\.gameType, fallback: true) }
    public var gameIdBinding: Binding<String?> { bind(\.gameId, fallback: nil) }
    public var gameResourcesTypeBinding: Binding<String> { bind(\.gameResourcesType, fallback: ResourceType.mod.rawValue) }
    public var selectedProjectIdBinding: Binding<String?> { bind(\.selectedProjectId, fallback: nil) }
    public var loadedProjectDetailBinding: Binding<ModrinthProjectDetail?> { bind(\.loadedProjectDetail, fallback: nil) }
    public var showInstallSheetBinding: Binding<Bool> { bind(\.showInstallSheet, fallback: false) }
}
