//
//  ContentToolbarView+Buttons.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import MinecraftFriendsKit
import SwiftUI

/// Dismisses a sheet binding after a 0.3s delay, allowing the sheet animation to complete
/// before resetting auth state.
private func delayedDismiss(_ binding: Binding<Bool>, execute work: @escaping @MainActor @Sendable () -> Void) {
    binding.wrappedValue = false
    Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(300))
        work()
    }
}

struct AddGameToolbarButton: View {
    let currentPlayer: Player?
    @State private var showForm = false
    @State private var activeAlert: ResourceButtonAlertType?

    var body: some View {
        Button {
            if currentPlayer == nil {
                activeAlert = .noPlayer
            } else {
                showForm.toggle()
            }
        } label: {
            Label("game.form.title".localized(), systemImage: "plus")
        }
        .help("game.form.title".localized())
        .sheet(isPresented: $showForm) {
            GameFormView()
                .presentationBackgroundInteraction(.automatic)
        }
        .alertItem(item: $activeAlert) { $0.alert }
    }
}

struct AddPlayerToolbarButton: View {
    @Environment(DIContainer.self)
    private var container
    @Environment(PlayerListViewModel.self)
    private var playerListViewModel

    @State private var showSheet = false
    @State private var playerName = ""
    @State private var isPlayerNameValid = false

    var body: some View {
        Button {
            playerName = ""
            isPlayerNameValid = false
            showSheet = true
        } label: {
            Label("player.add".localized(), systemImage: "person.badge.plus")
        }
        .help("player.add".localized())
        .sheet(isPresented: $showSheet) {
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
                    showSheet = false
                },
                onCancel: {
                    delayedDismiss($showSheet) {
                        container.system.minecraftAuthService.clearAuthenticationData()
                    }
                },
                onLogin: { profile in
                    AppLog.main.debug("Premium login successful, user: \(profile.name)")
                    _ = playerListViewModel.addOnlinePlayer(profile: profile)
                    container.system.premiumAccountFlagManager.setPremiumAccountAdded()
                    delayedDismiss($showSheet) {
                        container.system.minecraftAuthService.clearAuthenticationData()
                    }
                },
                onYggdrasilLogin: { profile in
                    AppLog.main.debug("Yggdrasil login successful, user: \(profile.name)")
                    OfflineUserServerMap.setServer(profile)
                    _ = playerListViewModel.addOnlinePlayer(profile: profile)
                    delayedDismiss($showSheet) {
                        container.system.yggdrasilAuthService.logout()
                    }
                },
                playerListViewModel: playerListViewModel,
            )
        }
    }
}

struct SkinToolbarButton: View {
    let isLoadingSkin: Bool
    let currentPlayer: Player?
    let viewModel: ContentToolbarViewModel
    @State private var showSheet = false

    var body: some View {
        Button {
            Task {
                await viewModel.preloadSkinDataForManager(player: currentPlayer)
                if currentPlayer != nil, !Task.isCancelled {
                    showSheet = true
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
        .sheet(isPresented: $showSheet) {
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

    let currentPlayer: Player?
    let viewModel: MinecraftFriendsSheetViewModel
    @State private var showSheet = false
    @State private var sheetHost: MinecraftFriendsSheetHostAdapter?
    @State private var isLoading = false

    var body: some View {
        Button {
            Task {
                guard let p = currentPlayer else { return }
                isLoading = true
                defer { isLoading = false }
                let host = MinecraftFriendsSheetHostAdapter(player: p)
                sheetHost = host
                viewModel.prepare(playerId: p.id, host: host)
                await viewModel.load(forceRefresh: false)
                guard !Task.isCancelled else { return }
                showSheet = true
            }
        } label: {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label("minecraft.friends.toolbar.title".localized(), systemImage: "person.2")
            }
        }
        .help("minecraft.friends.toolbar.help".localized())
        .disabled(isLoading)
        .sheet(isPresented: $showSheet) {
            if let p = currentPlayer, sheetHost != nil {
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
                    sheetHost = nil
                }
            }
        }
    }
}
