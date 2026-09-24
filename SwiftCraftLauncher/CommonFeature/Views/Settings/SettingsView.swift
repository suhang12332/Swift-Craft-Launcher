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

private struct SettingsSearchItem: Identifiable {
    let page: SettingsPage
    let key: String

    var id: String { key }
    var title: String { key.localized() }
}

private struct SettingsFocusRequest: Equatable {
    let id = UUID()
    let setting: String
}

/// macOS-style sidebar and grouped settings forms.
public struct SettingsView: View {
    @Environment(DIContainer.self)
    private var container
    @Environment(PlayerListViewModel.self)
    private var playerListViewModel
    @State private var selectedPage: SettingsPage? = .general
    @State private var lastAvailablePage: SettingsPage = .general
    @State private var searchText = ""
    @State private var focusRequest: SettingsFocusRequest?
    @State private var canAddOffline = false

    private let searchableSettings: [SettingsSearchItem] = [
        .init(page: .general, key: "settings.language.picker"),
        .init(page: .general, key: "settings.common_sheet_height_limit.label"),
        .init(page: .appearance, key: "settings.theme.picker"),
        .init(page: .appearance, key: "settings.interface_style.label"),
        .init(page: .files, key: "settings.launcher_working_directory"),
        .init(page: .network, key: "settings.system_proxy.label"),
        .init(page: .network, key: "settings.default_api_source.label"),
        .init(page: .player, key: "settings.player.ephemeral_login"),
        .init(page: .player, key: "settings.player.offline_login"),
        .init(page: .player, key: "settings.player.default_skin_server"),
        .init(page: .player, key: "settings.player.history_skin_library"),
        .init(page: .player, key: "settings.player.minecraft_friends_presence_notifications"),
        .init(page: .player, key: "settings.player.minecraft_friends_account.section"),
        .init(page: .player, key: "settings.player.authlib_injector"),
        .init(page: .downloads, key: "settings.modpack.export.format.label"),
        .init(page: .downloads, key: "settings.concurrent_downloads.label"),
        .init(page: .downloads, key: "settings.game_versions.label"),
        .init(page: .downloads, key: "settings.game.language.label"),
        .init(page: .java, key: "settings.memory_pressure_warning.label"),
        .init(page: .java, key: "settings.default_memory_allocation.label"),
        .init(page: .java, key: "settings.game.java.runtimes.section"),
        .init(page: .ai, key: "settings.ai_crash_analysis"),
        .init(page: .ai, key: "settings.ai.api_type.label"),
        .init(page: .ai, key: "settings.ai.api_key.label"),
        .init(page: .ai, key: "settings.ai.api_url.label"),
        .init(page: .ai, key: "settings.ai.ollama.url.label"),
        .init(page: .ai, key: "settings.ai.model.label"),
        .init(page: .ai, key: "settings.ai.avatar.label"),
        .init(page: .advanced, key: "settings.game.java.garbage_collector"),
        .init(page: .advanced, key: "settings.game.java.path"),
        .init(page: .advanced, key: "settings.game.java.performance_optimization"),
        .init(page: .advanced, key: "settings.game.java.memory"),
        .init(page: .advanced, key: "settings.game.java.custom_parameters"),
        .init(page: .advanced, key: "settings.game.java.environment_variables"),
    ]

    private var searchResults: [SettingsSearchItem] {
        guard !searchText.isEmpty else { return [] }
        return searchableSettings.filter { item in
            (item.page != .advanced || container.core.selectedGameManager.selectedGameId != nil)
                && (item.key != "settings.player.offline_login" || canAddOffline)
                && (!onlinePlayerSettings.contains(item.key) || playerListViewModel.currentPlayer?.isOnlineAccount == true)
                && (item.key != "settings.ai.api_url.label" || container.ui.aiSettingsManager.selectedProvider == .openai)
                && (item.key != "settings.ai.ollama.url.label" || container.ui.aiSettingsManager.selectedProvider == .ollama)
                && (item.title.localizedStandardContains(searchText) || item.page.title.localizedStandardContains(searchText))
        }
    }

    private var onlinePlayerSettings: Set<String> {
        [
            "settings.player.history_skin_library",
            "settings.player.minecraft_friends_presence_notifications",
            "settings.player.minecraft_friends_account.section",
        ]
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: $selectedPage) {
                if searchText.isEmpty {
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
                } else {
                    ForEach(searchResults) { item in
                        Button {
                            selectedPage = item.page
                            focusRequest = SettingsFocusRequest(setting: item.id)
                            searchText = ""
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                Text(item.page.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, placement: .sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 215, max: 260)
        } detail: {
            ScrollViewReader { proxy in
                detail
                    .id(selectedPage)
                    .navigationTitle(selectedPage?.title ?? "settings.general.tab".localized())
                    .onChange(of: focusRequest) { _, request in
                        guard let request else { return }
                        Task { @MainActor in
                            await Task.yield()
                            withAnimation { proxy.scrollTo(request.setting, anchor: .center) }
                        }
                    }
                    .onAppear {
                        if let focusRequest {
                            proxy.scrollTo(focusRequest.setting, anchor: .center)
                        }
                    }
            }
        }
        .frame(minWidth: 715, minHeight: 500)
        .onChange(of: container.core.selectedGameManager.shouldOpenAdvancedSettings) { _, shouldOpen in
            if shouldOpen {
                checkAndOpenAdvancedSettings()
            }
        }
        .onChange(of: selectedPage) { _, page in
            if page == .advanced, container.core.selectedGameManager.selectedGameId == nil {
                selectedPage = lastAvailablePage
            } else if let page {
                lastAvailablePage = page
            }
        }
        .onAppear {
            checkAndOpenAdvancedSettings()
        }
        .task {
            canAddOffline = await container.system.premiumAccountFlagManager.canAddOfflineAccount(
                ipLocationService: container.system.ipLocationService,
            )
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
