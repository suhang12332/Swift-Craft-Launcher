//
//  ResourceDetailState.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Aggregates sidebar selection, game/resource type, and project detail state.
///
/// Intended to be provided via `@EnvironmentObject` to reduce `@Binding` proliferation.
public final class ResourceDetailState: ObservableObject {

    @Published public var selectedItem: SidebarItem
    @Published public var gameType: Bool  // false = local, true = server
    @Published public var gameId: String?
    @Published public var gameResourcesType: String
    @Published public var selectedProjectId: String? {
        didSet {
            if selectedProjectId != oldValue {
                loadedProjectDetail = nil
            }
        }
    }
    @Published public var loadedProjectDetail: ModrinthProjectDetail?
    @Published public var showInstallSheet: Bool = false
    @Published public var currentProject: ModrinthProject?
    @Published var compatibleGames: [GameVersionInfo] = []

    public init(
        selectedItem: SidebarItem = .resource(.mod),
        gameType: Bool = true,
        gameId: String? = nil,
        gameResourcesType: String = ResourceType.mod.rawValue,
        selectedProjectId: String? = nil,
        loadedProjectDetail: ModrinthProjectDetail? = nil,
        loadedProjectDetailV3: ModrinthProjectDetailV3? = nil
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

    public var selectedItemBinding: Binding<SidebarItem> {
        Binding(get: { [weak self] in self?.selectedItem ?? .resource(.mod) }, set: { [weak self] value in
            guard let self else { return }
            DispatchQueue.main.async { self.selectedItem = value }
        })
    }

    /// Returns a binding suitable for APIs that require an optional selection (e.g. `List(selection:)`).
    public var selectedItemOptionalBinding: Binding<SidebarItem?> {
        Binding(get: { [weak self] in self?.selectedItem }, set: { [weak self] value in
            guard let self else { return }
            DispatchQueue.main.async { if let v = value { self.selectedItem = v } }
        })
    }
    public var gameTypeBinding: Binding<Bool> {
        Binding(get: { [weak self] in self?.gameType ?? true }, set: { [weak self] value in
            guard let self else { return }
            DispatchQueue.main.async { self.gameType = value }
        })
    }
    public var gameIdBinding: Binding<String?> {
        Binding(get: { [weak self] in self?.gameId }, set: { [weak self] value in
            guard let self else { return }
            DispatchQueue.main.async { self.gameId = value }
        })
    }
    public var gameResourcesTypeBinding: Binding<String> {
        Binding(get: { [weak self] in self?.gameResourcesType ?? ResourceType.mod.rawValue }, set: { [weak self] value in
            guard let self else { return }
            DispatchQueue.main.async { self.gameResourcesType = value }
        })
    }
    public var selectedProjectIdBinding: Binding<String?> {
        Binding(get: { [weak self] in self?.selectedProjectId }, set: { [weak self] value in
            guard let self else { return }
            DispatchQueue.main.async { self.selectedProjectId = value }
        })
    }
    public var loadedProjectDetailBinding: Binding<ModrinthProjectDetail?> {
        Binding(get: { [weak self] in self?.loadedProjectDetail }, set: { [weak self] value in
            guard let self else { return }
            DispatchQueue.main.async { self.loadedProjectDetail = value }
        })
    }
    public var showInstallSheetBinding: Binding<Bool> {
        Binding(get: { [weak self] in self?.showInstallSheet ?? false }, set: { [weak self] value in
            guard let self else { return }
            DispatchQueue.main.async { self.showInstallSheet = value }
        })
    }
}
