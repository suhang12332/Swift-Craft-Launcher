//
//  SettingsView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, game, player, ai, advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "settings.general.tab".localized()
        case .game: "settings.game.tab".localized()
        case .player: "settings.player.tab".localized()
        case .ai: "settings.ai.tab".localized()
        case .advanced: "settings.game.advanced.tab".localized()
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .game: "gamecontroller"
        case .player: "person.crop.circle"
        case .ai: "sparkles"
        case .advanced: "slider.horizontal.3"
        }
    }

    var color: Color {
        switch self {
        case .general: .gray
        case .game: .blue
        case .player: .green
        case .ai: .purple
        case .advanced: .gray
        }
    }
}

/// macOS-style sidebar and grouped settings forms.
public struct SettingsView: View {
    @Environment(DIContainer.self)
    private var container
    @State private var selectedPage: SettingsPage? = .general

    public var body: some View {
        NavigationSplitView {
            List(selection: $selectedPage) {
                ForEach(SettingsPage.allCases.filter { page in
                    page != .advanced || container.core.selectedGameManager.selectedGameId != nil
                }) { page in
                    Label {
                        Text(page.title)
                    } icon: {
                        Image(systemName: page.symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 23, height: 23)
                            .background(page.color.gradient, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .tag(page)
                }
            }
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(215)
        } detail: {
            detail
                .navigationTitle(visiblePage.title)
        }
        .toggleStyle(.switch)
        .frame(minWidth: 715, minHeight: 500)
        .onChange(of: container.core.selectedGameManager.shouldOpenAdvancedSettings) { _, shouldOpen in
            if shouldOpen {
                checkAndOpenAdvancedSettings()
            }
        }
        .onChange(of: container.core.selectedGameManager.selectedGameId) { _, gameID in
            if gameID == nil, selectedPage == .advanced {
                selectedPage = .general
            }
        }
        .onAppear {
            if container.core.selectedGameManager.selectedGameId == nil, selectedPage == .advanced {
                selectedPage = .general
            }
            checkAndOpenAdvancedSettings()
        }
    }

    private var visiblePage: SettingsPage {
        if selectedPage == .advanced, container.core.selectedGameManager.selectedGameId == nil {
            return .general
        }
        return selectedPage ?? .general
    }

    @ViewBuilder private var detail: some View {
        switch visiblePage {
        case .general:
            GeneralSettingsView()
                .environment(container.ui.gameSettingsManager)
        case .game:
            GameSettingsView()
                .environment(container.ui.gameSettingsManager)
        case .player:
            PlayerSettingsView()
                .environment(container.ui.playerSettingsManager)
        case .ai:
            AISettingsView()
                .environment(container.ui.aiSettingsManager)
                .environment(container.ui.gameSettingsManager)
        case .advanced:
            GameAdvancedSettingsView()
        }
    }

    private func checkAndOpenAdvancedSettings() {
        if container.core.selectedGameManager.shouldOpenAdvancedSettings,
           container.core.selectedGameManager.selectedGameId != nil {
            selectedPage = .advanced
            container.core.selectedGameManager.shouldOpenAdvancedSettings = false
        }
    }
}
