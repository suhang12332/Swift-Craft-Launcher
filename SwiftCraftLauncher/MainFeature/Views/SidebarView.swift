//
//  SidebarView.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Sidebar view for navigating between game and resource sections.
public struct SidebarView: View {
    @EnvironmentObject private var detailState: ResourceDetailState
    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var gameLaunchUseCase: GameLaunchUseCase
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @EnvironmentObject private var gameActionManager: GameActionManager
    @EnvironmentObject private var gameStatusManager: GameStatusManager
    @State private var searchText: String = ""
    @ObservedObject private var gameDialogsPresenter: GameDialogsPresenter
    @ObservedObject private var selectedGameManager: SelectedGameManager
    @StateObject private var viewModel = SidebarViewModel()

    @Environment(\.openSettings)
    private var openSettings

    /// Creates a sidebar view with the required presenters.
    /// - Parameters:
    ///   - gameDialogsPresenter: Handles game dialog presentations.
    ///   - selectedGameManager: Tracks the currently selected game.
    init(
        gameDialogsPresenter: GameDialogsPresenter = AppServices.gameDialogsPresenter,
        selectedGameManager: SelectedGameManager = AppServices.selectedGameManager,
    ) {
        _gameDialogsPresenter = ObservedObject(wrappedValue: gameDialogsPresenter)
        _selectedGameManager = ObservedObject(wrappedValue: selectedGameManager)
    }

    public var body: some View {
        List(selection: detailState.selectedItemOptionalBinding) {
            Section(header: Text("sidebar.resources.title".localized())) {
                ForEach(ResourceType.allCases, id: \.self) { type in
                    NavigationLink(value: SidebarItem.resource(type)) {
                        HStack(spacing: 6) {
                            Label(type.localizedName, systemImage: type.systemImage)
                        }
                    }
                }
            }

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
                        }
                        .tag(game.id)
                    }
                    .contextMenu {
                        GameContextMenu(
                            game: game,
                            onDelete: { gameDialogsPresenter.requestGameDeletion(of: game) },
                            onOpenSettings: { openSettings() },
                            onExport: {
                                gameDialogsPresenter.presentModPackExport(for: game)
                            },
                        )
                    }
                }
            }

            if !filteredCorruptedGames.isEmpty {
                Section(header: Text("sidebar.corrupted_games.title".localized())) {
                    ForEach(filteredCorruptedGames, id: \.self) { name in
                        HStack(spacing: 6) {
                            Label(name, systemImage: "exclamationmark.triangle")
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                gameActionManager.deleteCorruptedGame(
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
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return gameRepository.games
        }
        let lower = searchText.lowercased()
        return gameRepository.games.filter { $0.gameName.lowercased().contains(lower) }
    }

    private var filteredCorruptedGames: [String] {
        let names = gameRepository.corruptedGames
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return names
        }
        let lower = trimmed.lowercased()
        return names.filter { $0.lowercased().contains(lower) }
    }
}
