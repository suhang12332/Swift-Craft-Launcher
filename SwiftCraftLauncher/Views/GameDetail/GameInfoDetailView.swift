//
//  GameInfoDetailView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/2.
//

import SwiftUI

// MARK: - Window Delegate
// 已移除 NSWindowDelegate 相关代码，纯 SwiftUI 不再需要

// MARK: - Views
struct GameInfoDetailView: View {
    let game: GameVersionInfo

    @Binding var query: String
    @Binding var sortIndex: String
    @Binding var selectedVersions: [String]
    @Binding var selectedCategories: [String]
    @Binding var selectedFeatures: [String]
    @Binding var selectedResolutions: [String]
    @Binding var selectedPerformanceImpact: [String]
    @Binding var selectedProjectId: String?
    @Binding var selectedLoaders: [String]
    @Binding var gameType: Bool  // false = local, true = server
    @EnvironmentObject var gameRepository: GameRepository
    @Binding var selectedItem: SidebarItem
    @StateObject private var cacheManager = CacheManager()
    @State private var localRefreshToken = UUID()

    var body: some View {
        return Group {
            if gameType {
                GameRemoteResourceView(
                    game: game,
                    query: $query,
                    sortIndex: $sortIndex,
                    selectedVersions: $selectedVersions,
                    selectedCategories: $selectedCategories,
                    selectedFeatures: $selectedFeatures,
                    selectedResolutions: $selectedResolutions,
                    selectedPerformanceImpact: $selectedPerformanceImpact,
                    selectedProjectId: $selectedProjectId,
                    selectedLoaders: $selectedLoaders,
                    selectedItem: $selectedItem,
                    gameType: $gameType,
                    header: AnyView(
                        GameHeaderListRow(
                            game: game,
                            cacheInfo: cacheManager.cacheInfo,
                            query: query
                        ) {
                            triggerLocalRefresh()
                        }
                    )
                )
            } else {
                GameLocalResourceView(
                    game: game,
                    query: query,
                    header: AnyView(
                        GameHeaderListRow(
                            game: game,
                            cacheInfo: cacheManager.cacheInfo,
                            query: query
                        ) {
                            triggerLocalRefresh()
                        }
                    ),
                    selectedItem: $selectedItem,
                    selectedProjectId: $selectedProjectId,
                    refreshToken: localRefreshToken
                )
            }
        }
        // 优化：合并相关 onChange 以减少不必要的视图更新
        .onChange(of: game.gameName) { _, _ in
            cacheManager.calculateGameCacheInfo(game.gameName)
            triggerLocalRefresh()
        }
        .onChange(of: gameType) { oldValue, newValue in
            // 仅在 gameType 实际变化时扫描资源
            if oldValue != newValue {
                if newValue == false {
                    triggerLocalRefresh()
                }
            }
        }
        .onChange(of: query) { oldValue, newValue in
            // 仅在 query 实际变化时扫描资源
            if oldValue != newValue {
                triggerLocalRefresh()
            }
        }
        .onAppear {
            cacheManager.calculateGameCacheInfo(game.gameName)
        }
    }

    private func triggerLocalRefresh() {
        localRefreshToken = UUID()
    }
}
