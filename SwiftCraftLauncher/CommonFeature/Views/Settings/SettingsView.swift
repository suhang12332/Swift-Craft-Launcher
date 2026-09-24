//
//  SettingsView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, appearance, files, network, player, downloads, java, ai, advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "settings.general.tab".localized()
        case .appearance: "settings.category.appearance".localized()
        case .files: "settings.category.files".localized()
        case .network: "settings.category.network".localized()
        case .player: "settings.player.tab".localized()
        case .downloads: "settings.category.downloads".localized()
        case .java: "settings.category.java".localized()
        case .ai: "settings.ai.tab".localized()
        case .advanced: "settings.game.advanced.tab".localized()
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintbrush"
        case .files: "folder"
        case .network: "network"
        case .player: "person.crop.circle"
        case .downloads: "arrow.down.circle"
        case .java: "cpu"
        case .ai: "sparkles"
        case .advanced: "slider.horizontal.3"
        }
    }

    var color: Color {
        switch self {
        case .general: .gray
        case .appearance: .blue
        case .files: .orange
        case .network: .purple
        case .player: .green
        case .downloads: .blue
        case .java: .orange
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
    @State private var lastAvailablePage: SettingsPage = .general

    public var body: some View {
        NavigationSplitView {
            List(selection: $selectedPage) {
                ForEach(SettingsPage.allCases) { page in
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
                    .disabled(page == .advanced && container.core.selectedGameManager.selectedGameId == nil)
                    .allowsHitTesting(page != .advanced || container.core.selectedGameManager.selectedGameId != nil)
                }
            }
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(215)
        } detail: {
            VStack(spacing: 0) {
                Text(selectedPage?.title ?? "settings.general.tab".localized())
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                Divider()
                detail
            }
        }
        .toggleStyle(.switch)
        .frame(minWidth: 715, minHeight: 500)
        .onChange(of: container.core.selectedGameManager.shouldOpenAdvancedSettings) { _, shouldOpen in
            if shouldOpen {
                checkAndOpenAdvancedSettings()
            }
        }
        .onChange(of: selectedPage) { _, page in
            if page == .advanced, container.core.selectedGameManager.selectedGameId == nil {
                selectedPage = lastAvailablePage
            } else if let page, page != .advanced {
                lastAvailablePage = page
            }
        }
        .onChange(of: container.core.selectedGameManager.selectedGameId) { _, gameID in
            if gameID == nil, selectedPage == .advanced {
                selectedPage = lastAvailablePage
            }
        }
        .onAppear {
            checkAndOpenAdvancedSettings()
        }
    }

    @ViewBuilder private var detail: some View {
        switch selectedPage ?? .general {
        case .general, .appearance, .files, .network:
            GeneralSettingsView(page: selectedPage ?? .general)
                .environment(container.ui.gameSettingsManager)
        case .player:
            PlayerSettingsView()
                .environment(container.ui.playerSettingsManager)
        case .downloads, .java:
            GameSettingsView(page: selectedPage ?? .downloads)
                .environment(container.ui.gameSettingsManager)
        case .ai:
            AISettingsView()
                .environment(container.ui.aiSettingsManager)
                .environment(container.ui.gameSettingsManager)
        case .advanced:
            if container.core.selectedGameManager.selectedGameId != nil {
                GameAdvancedSettingsView()
            } else {
                GeneralSettingsView(page: .general)
            }
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
