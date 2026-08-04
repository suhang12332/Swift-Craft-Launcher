//
//  SettingsView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// An enumeration of settings tabs.
enum SettingsTab: Int {
    case general = 0
    case player = 1
    case game = 2
    case advanced = 3
    case ai = 4
}

/// The main settings view with tabbed navigation.
public struct SettingsView: View {
    @Environment(DIContainer.self)
    private var container
    @Environment(GameRepository.self)
    private var gameRepository
    @State private var selectedTab: SettingsTab = .general

    public var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("settings.general.tab".localized(), systemImage: "gearshape")
                }
                .tag(SettingsTab.general)
            PlayerSettingsView()
                .environment(container.ui.playerSettingsManager)
                .tabItem {
                    Label("settings.player.tab".localized(), systemImage: "person")
                }
                .tag(SettingsTab.player)
            GameSettingsView()
                .environment(container.ui.gameSettingsManager)
                .tabItem {
                    Label("settings.game.tab".localized(), systemImage: "gamecontroller")
                }
                .tag(SettingsTab.game)
            AISettingsView()
                .environment(container.ui.aiSettingsManager)
                .tabItem {
                    Label("settings.ai.tab".localized(), systemImage: "brain")
                }
                .tag(SettingsTab.ai)
            GameAdvancedSettingsView()
                .tabItem {
                    Label(
                        "settings.game.advanced.tab".localized(),
                        systemImage: "gearshape.2",
                    )
                }
                .tag(SettingsTab.advanced)
                .disabled(container.core.selectedGameManager.selectedGameId == nil)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .onChange(of: container.core.selectedGameManager.shouldOpenAdvancedSettings) { _, shouldOpen in
            if shouldOpen {
                checkAndOpenAdvancedSettings()
            }
        }
        .onAppear {
            checkAndOpenAdvancedSettings()
        }
    }

    private func checkAndOpenAdvancedSettings() {
        if container.core.selectedGameManager.shouldOpenAdvancedSettings, container.core.selectedGameManager.selectedGameId != nil {
            selectedTab = .advanced
            container.core.selectedGameManager.shouldOpenAdvancedSettings = false
        }
    }
}
