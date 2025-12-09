//
//  RootView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/28.
//

import SwiftUI

/// 根视图 - 根据条件显示游戏中心或主视图
struct RootView: View {
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @EnvironmentObject var gameRepository: GameRepository
    @State private var isInitialLoad = true
    @State private var showOnboarding = false

    // 计算属性：是否应该显示游戏中心
    // 由于 games 和 currentPlayer 都是 @Published，当数据加载完成后会自动触发视图更新
    private var shouldShowGameHub: Bool {
        playerListViewModel.currentPlayer != nil && !gameRepository.games.isEmpty
    }

    var body: some View {
        Group {
            if isInitialLoad {
                // 初始加载时显示加载视图，等待数据加载完成
                LoadingView()
                    .task {
                        // 等待数据加载完成
                        await waitForInitialDataLoad()
                        isInitialLoad = false
                        
                        // 检查是否需要显示引导
                        if !OnboardingManager.shared.hasShownOnboarding {
                            showOnboarding = true
                        }
                    }
            } else {
                // 数据加载完成后，根据条件显示对应视图
                if shouldShowGameHub {
                    GameHubView()
                } else {
                    MainView()
                }
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(
                interactor: OnboardingInteractor(
                    didSelectGetStarted: {
                        OnboardingManager.shared.markOnboardingAsShown()
                        showOnboarding = false
                    }
                )
            )
        }
    }

    /// 等待初始数据加载完成
    private func waitForInitialDataLoad() async {
        // 等待一小段时间，确保异步加载的数据已经完成
        // GameRepository 的 loadGamesSafely 是异步的，需要等待
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒

        // 如果数据还没加载完，继续等待（最多等待2秒）
        var waitCount = 0
        let maxWaitCount = 40 // 40 * 0.05 = 2秒
        
        while waitCount < maxWaitCount {
            // 检查数据是否已加载（玩家列表已加载，游戏列表可能还在加载）
            // 如果已经有数据或者明确为空（已加载完成），则退出
            if !playerListViewModel.players.isEmpty || !gameRepository.games.isEmpty {
                // 有数据了，再等待一小段时间确保数据完整
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                break
            }

            // 如果玩家列表为空且游戏列表也为空，可能是：
            // 1. 数据还在加载中
            // 2. 确实没有数据
            // 等待一段时间后如果还是空的，就认为加载完成了
            if waitCount > 10 { // 0.5秒后如果还是空的，认为加载完成
                break
            }
            
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
            waitCount += 1
        }
    }
}

/// 加载视图
private struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView().controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
