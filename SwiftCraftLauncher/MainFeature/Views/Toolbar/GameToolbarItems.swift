//
//  GameToolbarItems.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Composes the detail toolbar layout for a selected game, combining filter menus and action buttons.
struct GameToolbarItems: View {
    let game: GameVersionInfo

    @Environment(\.controlActiveState)
    private var controlActiveState
    @EnvironmentObject private var filterState: ResourceFilterState
    @EnvironmentObject private var detailState: ResourceDetailState

    var body: some View {
        ResourceFilterMenus.resourcesTypeMenu(detailState: detailState)
            .id(controlActiveState)
        ResourceFilterMenus.resourcesMenu(currentGame: game, detailState: detailState)
            .id(controlActiveState)
        if detailState.gameType {
            ResourceFilterMenus.dataSourceMenu(filterState: filterState)
                .id(controlActiveState)
        } else {
            ResourceFilterMenus.localResourceFilterMenu(filterState: filterState)
                .id(controlActiveState)
        }

        Spacer()

        GameActionButtons(game: game)
    }
}
