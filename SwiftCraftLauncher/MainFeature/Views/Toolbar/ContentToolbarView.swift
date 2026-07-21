//
//  ContentToolbarView.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import MinecraftFriendsKit
import SwiftUI

/// Provides the primary toolbar content for the main content area.
public struct ContentToolbarView: ToolbarContent {
    @EnvironmentObject private var container: DIContainer
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @State private var showingAddPlayerSheet = false
    @State private var playerName = ""
    @State private var isPlayerNameValid = false
    @State private var showPlayerAlert = false
    @State private var showingGameForm = false
    @EnvironmentObject private var gameRepository: GameRepository
    @State private var showEditSkin = false
    @State private var showingMinecraftFriendsSheet = false
    @State private var minecraftFriendsSheetHost: MinecraftFriendsSheetHostAdapter?
    @State private var viewModel = ContentToolbarViewModel()
    @State private var minecraftFriendsSheetViewModel = MinecraftFriendsSheetViewModel(friendsService: DIContainer.shared.ui.minecraftFriendsService)

    private var currentPlayer: Player? {
        playerListViewModel.currentPlayer
    }

    private var isCurrentPlayerOnline: Bool {
        currentPlayer?.isOnlineAccount ?? false
    }

    public var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                if currentPlayer == nil {
                    showPlayerAlert = true
                } else {
                    showingGameForm.toggle()
                }
            } label: {
                Label("game.form.title".localized(), systemImage: "plus")
            }
            .help("game.form.title".localized())
            .sheet(isPresented: $showingGameForm) {
                GameFormView()
                    .presentationBackgroundInteraction(.automatic)
            }
            Spacer()
            Button {
                playerName = ""
                isPlayerNameValid = false
                showingAddPlayerSheet = true
            } label: {
                Label("player.add".localized(), systemImage: "person.badge.plus")
            }
            .help("player.add".localized())
            .sheet(isPresented: $showingAddPlayerSheet) {
                AddPlayerSheetView(
                    playerName: $playerName,
                    isPlayerNameValid: $isPlayerNameValid,
                    onAdd: {
                        if playerListViewModel.addPlayer(name: playerName) {
                            AppLog.main.debug("Player \(playerName) added successfully (via ViewModel).")
                        } else {
                            AppLog.main.debug("Failed to add player \(playerName) (via ViewModel).")
                        }
                        isPlayerNameValid = true
                        showingAddPlayerSheet = false
                    },
                    onCancel: {
                        playerName = ""
                        isPlayerNameValid = false

                        showingAddPlayerSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            container.system.minecraftAuthService.clearAuthenticationData()
                        }
                    },
                    onLogin: { profile in
                        AppLog.main.debug("Premium login successful, user: \(profile.name)")
                        _ = playerListViewModel.addOnlinePlayer(profile: profile)
                        container.system.premiumAccountFlagManager.setPremiumAccountAdded()
                        showingAddPlayerSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            container.system.minecraftAuthService.clearAuthenticationData()
                        }
                    },
                    onYggdrasilLogin: { profile in
                        AppLog.main.debug("Yggdrasil login successful, user: \(profile.name)")
                        OfflineUserServerMap.setServer(profile)
                        _ = playerListViewModel.addOnlinePlayer(profile: profile)
                        showingAddPlayerSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            container.system.yggdrasilAuthService.logout()
                        }
                    },
                    playerListViewModel: playerListViewModel,
                )
            }
            .alert(isPresented: $showPlayerAlert) {
                Alert(
                    title: Text("sidebar.alert.no_player.title".localized()),
                    message: Text("sidebar.alert.no_player.message".localized()),
                    dismissButton: .default(Text("common.confirm".localized())),
                )
            }

            if isCurrentPlayerOnline {
                Button {
                    Task {
                        await viewModel.preloadSkinDataForManager(player: currentPlayer)
                        if currentPlayer != nil, !Task.isCancelled {
                            showEditSkin = true
                        }
                    }
                } label: {
                    if viewModel.isLoadingSkin {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("skin.title".localized(), systemImage: "tshirt")
                    }
                }
                .help("skin.title".localized())
                .disabled(viewModel.isLoadingSkin)
                .sheet(isPresented: $showEditSkin) {
                    SkinToolDetailView(
                        preloadedSkinInfo: viewModel.preloadedSkinInfo,
                        preloadedProfile: viewModel.preloadedProfile,
                    )
                    .onDisappear {
                        viewModel.clearPreloadedSkinData()
                    }
                }

                Button {
                    Task {
                        guard let p = currentPlayer else { return }
                        let host = MinecraftFriendsSheetHostAdapter(player: p)
                        minecraftFriendsSheetHost = host
                        minecraftFriendsSheetViewModel.prepare(playerId: p.id, host: host)
                        await minecraftFriendsSheetViewModel.load(forceRefresh: false)
                        guard !Task.isCancelled, currentPlayer?.id == p.id else { return }
                        showingMinecraftFriendsSheet = true
                    }
                } label: {
                    if minecraftFriendsSheetViewModel.isLoading, !showingMinecraftFriendsSheet {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("minecraft.friends.toolbar.title".localized(), systemImage: "person.2")
                    }
                }
                .help("minecraft.friends.toolbar.help".localized())
                .disabled(minecraftFriendsSheetViewModel.isLoading && !showingMinecraftFriendsSheet)
                .sheet(isPresented: $showingMinecraftFriendsSheet) {
                    if let p = currentPlayer, minecraftFriendsSheetHost != nil {
                        MinecraftFriendsSheetView(
                            playerId: p.id,
                            viewModel: minecraftFriendsSheetViewModel,
                            localize: MinecraftFriendsSheetLocalize.resolver(
                                localeIdentifier: { container.ui.languageManager.selectedLanguage },
                                fallback: { $0.localized() },
                            ),
                            limitBodyScrollHeight: container.ui.generalSettingsManager.limitCommonSheetHeight,
                        ) { _, url in
                            Group {
                                if let u = url, !u.isEmpty {
                                    MinecraftSkinUtils(type: .url, src: u, size: 40)
                                } else {
                                    ProgressView()
                                        .controlSize(.small)
                                        .frame(width: 40, height: 40)
                                }
                            }
                        }
                        .onDisappear {
                            minecraftFriendsSheetHost = nil
                        }
                    }
                }
            }
        }
    }
}
