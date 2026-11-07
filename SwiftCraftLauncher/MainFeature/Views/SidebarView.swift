//
//  SidebarView.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Sidebar view for navigating between game and resource sections.
public struct SidebarView: View {
    @Environment(DIContainer.self)
    private var container
    @Environment(ResourceDetailState.self)
    private var detailState
    @Environment(GameRepository.self)
    private var gameRepository
    @Environment(PlayerListViewModel.self)
    private var playerListViewModel
    @State private var searchText: String = ""
    @State private var viewModel = SidebarViewModel()

    @Environment(\.openSettings)
    private var openSettings

    public var body: some View {
        @Bindable var detailState = detailState
        let selection = Binding<SidebarItem?>(
            get: { detailState.selectedItem },
            set: { newValue in
                if let newValue {
                    detailState.selectedItem = newValue
                }
            },
        )
        List(selection: selection) {
            Section(header: Text("sidebar.resources.title".localized())) {
                ForEach(ResourceType.allCases, id: \.self) { type in
                    NavigationLink(value: SidebarItem.resource(type)) {
                        Label(type.localizedName, systemImage: type.systemImage)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if !gameRepository.games.isEmpty {
                Section(header: Text("sidebar.games.title".localized())) {
                    ForEach(filteredGames) { game in
                        NavigationLink(value: SidebarItem.game(game.id)) {
                            HStack(spacing: 6) {
                                GameIconView(
                                    game: game,
                                    refreshTrigger: viewModel.refreshTrigger(for: game.gameName),
                                )
                                Text(game.gameName)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .tag(game.id)
                        }
                        .contextMenu {
                            GameContextMenu(game: game) {
                                openSettings()
                            }
                        }
                    }
                }
            }

            if !filteredCorruptedGames.isEmpty {
                Section(header: Text("sidebar.corrupted_games.title".localized())) {
                    ForEach(filteredCorruptedGames, id: \.self) { name in
                        Label(name, systemImage: "exclamationmark.triangle")
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                            .contextMenu {
                                Button(role: .destructive) {
                                    container.core.gameActionManager.deleteCorruptedGame(
                                        name: name,
                                        gameRepository: gameRepository,
                                    )
                                } label: {
                                    Label("sidebar.context_menu.delete_game".localized(), systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "sidebar.search.games".localized())
        .safeAreaInset(edge: .bottom) {
            if !playerListViewModel.players.isEmpty {
                PlayerListView()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .listStyle(.sidebar)
        .onAppear {
            viewModel.onAppear(games: gameRepository.games)
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: gameRepository.games) { _, newGames in
            viewModel.onGamesChanged(newGames)
        }
    }

    private var filteredGames: [GameVersionInfo] {
        gameRepository.games.filter { matchesSearch($0.gameName) }
    }

    private var filteredCorruptedGames: [String] {
        gameRepository.corruptedGames.filter(matchesSearch)
    }

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func matchesSearch(_ text: String) -> Bool {
        searchQuery.isEmpty || text.lowercased().contains(searchQuery)
    }
}
