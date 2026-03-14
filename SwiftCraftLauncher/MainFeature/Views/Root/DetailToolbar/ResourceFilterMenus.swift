//
//  ResourceFilterMenus.swift
//  SwiftCraftLauncher
//

import SwiftUI

/// 详情工具栏中的资源筛选相关菜单（资源类型切换、数据源、本地筛选等）
enum ResourceFilterMenus {

    private static func resourceTypesForCurrentGame(currentGame: GameVersionInfo?) -> [String] {
        var types = ["datapack", "resourcepack"]
        if let game = currentGame, game.modLoader.lowercased() != "vanilla" {
            types.insert("mod", at: 0)
            types.insert("shader", at: 2)
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

    /// 资源内容位置切换（本地 / 服务端）
    @ViewBuilder
    static func resourcesTypeMenu(detailState: ResourceDetailState) -> some View {
        Button {
            detailState.gameType.toggle()
        } label: {
            Label(
                currentResourceTypeTitle(detailState: detailState),
                systemImage: detailState.gameType
                    ? "tray.and.arrow.down" : "icloud.and.arrow.down"
            ).foregroundStyle(.primary)
        }
        .help("resource.content.location.help".localized())
        .applyReplaceTransition()
    }

    /// 资源类型菜单（mod / datapack / resourcepack / shader）
    @ViewBuilder
    static func resourcesMenu(currentGame: GameVersionInfo?, detailState: ResourceDetailState) -> some View {
        Menu {
            ForEach(resourceTypesForCurrentGame(currentGame: currentGame), id: \.self) { sort in
                Button("resource.content.type.\(sort)".localized()) {
                    detailState.gameResourcesType = sort
                }
            }
        } label: {
            Label(currentResourceTitle(detailState: detailState), systemImage: "")
                .labelStyle(.titleOnly)
        }
    }

    /// 数据源菜单（Modrinth / CurseForge）
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

    /// 本地资源筛选菜单（全部 / 已禁用）
    @ViewBuilder
    static func localResourceFilterMenu(filterState: ResourceFilterState) -> some View {
        Menu {
            ForEach(LocalResourceFilter.allCases) { filter in
                Button(filter.title) {
                    filterState.localResourceFilter = filter
                }
            }
        } label: {
            Label(filterState.localResourceFilter.title, systemImage: "")
                .labelStyle(.titleOnly)
        }
    }
}
