//
//  ContentToolbarView+Buttons.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import MinecraftFriendsKit
import SwiftUI

// MARK: - Delayed Dismiss Helper

/// Dismisses a sheet binding after a 0.3s delay, allowing the sheet animation to complete
/// before resetting auth state.
private func delayedDismiss(_ binding: Binding<Bool>, execute work: @escaping () -> Void) {
    binding.wrappedValue = false
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
}

struct AddGameToolbarButton: View {
    @Binding var showingGameForm: Bool
    @Binding var showPlayerAlert: Bool
    let currentPlayer: Player?

    var body: some View {
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
        .alert(isPresented: $showPlayerAlert) {
            Alert(
                title: Text("sidebar.alert.no_player.title".localized()),
                message: Text("sidebar.alert.no_player.message".localized()),
                dismissButton: .default(Text("common.confirm".localized())),
            )
        }
    }
}

struct AddPlayerToolbarButton: View {
    @Environment(DIContainer.self)
    private var container
    @Environment(PlayerListViewModel.self)
    private var playerListViewModel

    @Binding var showingAddPlayerSheet: Bool
    @Binding var playerName: String
    @Binding var isPlayerNameValid: Bool

    var body: some View {
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
                    delayedDismiss($showingAddPlayerSheet) {
                        container.system.minecraftAuthService.clearAuthenticationData()
                    }
                },
                onLogin: { profile in
                    AppLog.main.debug("Premium login successful, user: \(profile.name)")
                    _ = playerListViewModel.addOnlinePlayer(profile: profile)
                    container.system.premiumAccountFlagManager.setPremiumAccountAdded()
                    delayedDismiss($showingAddPlayerSheet) {
                        container.system.minecraftAuthService.clearAuthenticationData()
                    }
                },
                onYggdrasilLogin: { profile in
                    AppLog.main.debug("Yggdrasil login successful, user: \(profile.name)")
                    OfflineUserServerMap.setServer(profile)
                    _ = playerListViewModel.addOnlinePlayer(profile: profile)
                    delayedDismiss($showingAddPlayerSheet) {
                        container.system.yggdrasilAuthService.logout()
                    }
                },
                playerListViewModel: playerListViewModel,
            )
        }
    }
}

struct SkinToolbarButton: View {
    @Binding var showEditSkin: Bool
    let isLoadingSkin: Bool
    let currentPlayer: Player?
    let viewModel: ContentToolbarViewModel

    var body: some View {
        Button {
            Task {
                await viewModel.preloadSkinDataForManager(player: currentPlayer)
                if currentPlayer != nil, !Task.isCancelled {
                    showEditSkin = true
                }
            }
        } label: {
            if isLoadingSkin {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label("skin.title".localized(), systemImage: "tshirt")
            }
        }
        .help("skin.title".localized())
        .disabled(isLoadingSkin)
        .sheet(isPresented: $showEditSkin) {
            SkinToolDetailView(
                preloadedSkinInfo: viewModel.preloadedSkinInfo,
                preloadedProfile: viewModel.preloadedProfile,
            )
            .onDisappear {
                viewModel.clearPreloadedSkinData()
            }
        }
    }
}

struct MinecraftFriendsToolbarButton: View {
    @Environment(DIContainer.self)
    private var container

    @Binding var showingMinecraftFriendsSheet: Bool
    @Binding var minecraftFriendsSheetHost: MinecraftFriendsSheetHostAdapter?
    @Binding var isLoadingFriends: Bool

    let currentPlayer: Player?
    let viewModel: MinecraftFriendsSheetViewModel

    var body: some View {
        Button {
            Task {
                guard let p = currentPlayer else { return }
                isLoadingFriends = true
                defer { isLoadingFriends = false }
                let host = MinecraftFriendsSheetHostAdapter(player: p)
                minecraftFriendsSheetHost = host
                viewModel.prepare(playerId: p.id, host: host)
                await viewModel.load(forceRefresh: false)
                guard !Task.isCancelled else { return }
                showingMinecraftFriendsSheet = true
            }
        } label: {
            if isLoadingFriends {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label("minecraft.friends.toolbar.title".localized(), systemImage: "person.2")
            }
        }
        .help("minecraft.friends.toolbar.help".localized())
        .disabled(isLoadingFriends)
        .sheet(isPresented: $showingMinecraftFriendsSheet) {
            if let p = currentPlayer, minecraftFriendsSheetHost != nil {
                MinecraftFriendsSheetView(
                    playerId: p.id,
                    viewModel: viewModel,
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
