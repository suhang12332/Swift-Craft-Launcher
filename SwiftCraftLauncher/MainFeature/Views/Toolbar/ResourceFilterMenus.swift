//
//  ResourceFilterMenus.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Provides static menu builders for filtering resources in the detail toolbar.
enum ResourceFilterMenus {

    private static func resourceTypesForCurrentGame(currentGame: GameVersionInfo?) -> [String] {
        var types = [ResourceType.datapack.rawValue, ResourceType.resourcepack.rawValue]
        if let game = currentGame, game.modLoader.lowercased() != GameLoader.vanilla.displayName {
            types.insert(ResourceType.mod.rawValue, at: 0)
            types.insert(ResourceType.shader.rawValue, at: 2)
        }
        return types
    }

    private static func currentResourceTitle(detailState: ResourceDetailState) -> String {
        "resource.content.type.\(detailState.gameResourcesType)".localized()
    }

    private static func currentResourceTypeTitle(detailState: ResourceDetailState) -> String {
        detailState.gameType
            ? "resource.content.type.server".localized()
            : "resource.content.type.local".localized()
    }

    /// Toggles the resource content location between local and remote.
    @ViewBuilder
    static func resourcesTypeMenu(detailState: ResourceDetailState) -> some View {
        Button {
            detailState.gameType.toggle()
        } label: {
            Label(
                currentResourceTypeTitle(detailState: detailState),
                systemImage: detailState.gameType
                    ? "tray.and.arrow.down" : "icloud.and.arrow.down"
            )
            .foregroundStyle(.primary)
            .applyReplaceTransition()
        }
        .help("resource.content.location.help".localized())
    }

    /// Displays a menu for selecting the active resource type (mod, datapack, resourcepack, or shader).
    @ViewBuilder
    static func resourcesMenu(currentGame: GameVersionInfo?, detailState: ResourceDetailState) -> some View {
        Menu {
            ForEach(resourceTypesForCurrentGame(currentGame: currentGame), id: \.self) { sort in
                Button("resource.content.type.\(sort)".localized()) {
                    detailState.gameResourcesType = sort
                }
            }
        } label: {
            Label(currentResourceTitle(detailState: detailState), systemImage: ResourceType(rawValue: detailState.gameResourcesType)?.systemImage ?? "folder")
        }
    }

    /// Presents a menu for choosing between data sources such as Modrinth or CurseForge.
    @ViewBuilder
    static func dataSourceMenu(filterState: ResourceFilterState) -> some View {
        Menu {
            ForEach(DataSource.allCases, id: \.self) { source in
                Button(source.localizedName) {
                    filterState.dataSource = source
                }
            }
        } label: {
            Label(filterState.dataSource.localizedName, systemImage: "")
                .labelStyle(.titleOnly)
        }
    }

    /// Provides a menu for filtering local resources by status, such as all or disabled.
    @ViewBuilder
    static func localResourceFilterMenu(filterState: ResourceFilterState) -> some View {
        Menu {
            ForEach(LocalResourceFilter.allCases) { filter in
                Button(filter.title) {
                    filterState.localResourceFilter = filter
                }
            }
        } label: {
            Label(filterState.localResourceFilter.title, systemImage: filterState.localResourceFilter.icon)
        }
    }
}
