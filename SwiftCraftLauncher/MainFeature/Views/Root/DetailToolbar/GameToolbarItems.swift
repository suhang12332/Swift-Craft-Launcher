//
//  GameToolbarItems.swift
//  SwiftCraftLauncher
//

import SwiftUI

/// 选中游戏时的详情工具栏内容：筛选菜单 + 操作按钮
struct GameToolbarItems: View {
    let game: GameVersionInfo

    @EnvironmentObject var filterState: ResourceFilterState
    @EnvironmentObject var detailState: ResourceDetailState

    var body: some View {
        ResourceFilterMenus.resourcesTypeMenu(detailState: detailState)
        ResourceFilterMenus.resourcesMenu(currentGame: game, detailState: detailState)
        if detailState.gameType {
            ResourceFilterMenus.dataSourceMenu(filterState: filterState)
        } else {
            ResourceFilterMenus.localResourceFilterMenu(filterState: filterState)
        }

        Spacer()

        GameActionButtons(game: game)
    }
}
