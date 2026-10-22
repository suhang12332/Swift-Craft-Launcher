//
//  AddPlayerSheetView.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Provides the UI for adding a new player via Microsoft, Yggdrasil, or offline authentication.
struct AddPlayerSheetView: View {
    @Environment(DIContainer.self)
    private var container
    @Environment(PlayerListViewModel.self)
    private var playerListViewModel
    @Environment(\.dismiss)
    private var dismiss
    @State private var playerName: String = ""
    @State private var isPlayerNameValid: Bool = false
    var onCancel: () -> Void
    var onLogin: (MinecraftProfileResponse) -> Void
    var onYggdrasilLogin: ((YggdrasilProfile) -> Void)?

    enum PlayerProfile {
        case minecraft(MinecraftProfileResponse)
    }

    @State private var isPremium: Bool = false
    @State private var authenticatedProfile: MinecraftProfileResponse?
    @State private var viewModel = AddPlayerSheetViewModel()

    @Environment(\.openURL)
    private var openURL

    init(
        onCancel: @escaping () -> Void,
        onLogin: @escaping (MinecraftProfileResponse) -> Void,
        onYggdrasilLogin: ((YggdrasilProfile) -> Void)? = nil,
    ) {
        self.onCancel = onCancel
        self.onLogin = onLogin
        self.onYggdrasilLogin = onYggdrasilLogin
    }

    var body: some View {
        CommonSheetView(
            header: {
                HStack {
                    Text("addplayer.title".localized())
                        .font(.headline)
                    Image(systemName: viewModel.selectedAuthType.symbol.name)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(viewModel.selectedAuthType.symbol.mode)
                        .symbolVariant(.none)
                    if viewModel.selectedAuthType == .yggdrasil,
                       let serverName = container.system.yggdrasilAuthService.currentServer?.name {
                        Text(serverName)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if viewModel.isCheckingFlag {
                        ProgressView()
                            .controlSize(.small)
                            .frame(height: 20.5)
                            .padding(.trailing, 10)
                    } else {
                        authTypePicker
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            },
            body: {
                switch viewModel.selectedAuthType {
                case .premium:
                    MinecraftAuthView(onLoginSuccess: onLogin)
                case .yggdrasil:
                    YggdrasilAuthView(onLoginSuccess: onYggdrasilLogin)
                case .offline:
                    OfflineAuthView(playerName: $playerName, isPlayerNameValid: $isPlayerNameValid)
                }
            },
            footer: {
                HStack {
                    Button(
                        "common.cancel".localized(),
                    ) {
                        container.system.minecraftAuthService.isLoading = false
                        container.system.yggdrasilAuthService.logout()
                        onCancel()
                    }
                    Spacer()
                    switch viewModel.selectedAuthType {
                    case .premium:
                        switch container.system.minecraftAuthService.authState {
                        case .idle:
                            Button("addplayer.auth.start_login".localized()) {
                                Task {
                                    await viewModel.startPremiumAuthentication(authService: container.system.minecraftAuthService)
                                }
                            }
                            .keyboardShortcut(.defaultAction)

                        case let .authenticated(profile):
                            Button("addplayer.auth.add".localized()) {
                                onLogin(profile)
                            }
                            .keyboardShortcut(.defaultAction)

                        case .error:
                            Group {
                                if let issue = container.system.minecraftAuthService.authenticationIssue {
                                    Button(issue.buttonInfo.localized()) {
                                        openURL(issue.actionURL)
                                    }
                                } else {
                                    Button("addplayer.auth.retry".localized()) {
                                        Task {
                                            await viewModel.startPremiumAuthentication(
                                                authService: container.system.minecraftAuthService,
                                            )
                                        }
                                    }
                                }
                            }
                            .keyboardShortcut(.defaultAction)

                        default:
                            ProgressView().controlSize(.small)
                        }
                    case .yggdrasil:
                        switch container.system.yggdrasilAuthService.authState {
                        case .idle, .error:
                            Button("addplayer.auth.start_login".localized()) {
                                Task {
                                    await viewModel.startYggdrasilAuthentication(
                                        yggdrasilAuthService: container.system.yggdrasilAuthService,
                                    )
                                }
                            }
                            .keyboardShortcut(.defaultAction)
                            .disabled(container.system.yggdrasilAuthService.currentServer == nil)
                        case let .authenticated(profile):
                            Button("addplayer.auth.add".localized()) {
                                onYggdrasilLogin?(profile)
                            }
                            .keyboardShortcut(.defaultAction)
                        case .waitingForBrowser, .processing:
                            ProgressView().controlSize(.small)
                        }
                    default:
                        Button(
                            "addplayer.purchase.minecraft".localized(),
                        ) {
                            openURL(URLConfig.Store.minecraftPurchase)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)

                        Button(
                            "addplayer.create".localized(),
                        ) {
                            container.system.minecraftAuthService.isLoading = false
                            _ = playerListViewModel.addPlayer(name: playerName)
                            dismiss()
                        }
                        .disabled(!isPlayerNameValid)
                        .keyboardShortcut(.defaultAction)
                    }
                }
            },
        )
        .task {
            await viewModel.checkPremiumAccountFlag()
        }
        .onDisappear {
            clearAllData()
        }
    }

    private var authTypePicker: some View {
        Menu {
            ForEach(viewModel.availableAuthTypes) { type in
                Button(type.displayName) {
                    viewModel.selectedAuthType = type
                }
            }
        } label: {
            Text(viewModel.selectedAuthType.displayName)
        }
        .fixedSize()
    }

    /// Clears all data and resets authentication state when the sheet is dismissed.
    private func clearAllData() {
        playerName = ""
        isPlayerNameValid = false
        authenticatedProfile = nil
        isPremium = false
        container.system.minecraftAuthService.isLoading = false
        container.system.yggdrasilAuthService.logout()
        viewModel.reset()
    }
}

/// The type of account authentication available in the add-player sheet.
enum AccountAuthType: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    /// Microsoft (premium) account authentication.
    case premium
    /// Yggdrasil third-party authentication server.
    case yggdrasil
    /// Offline (local) account creation.
    case offline

    var displayName: String {
        switch self {
        case .premium:
            return "addplayer.auth.microsoft".localized()
        case .yggdrasil:
            return "addplayer.auth.yggdrasil".localized()
        case .offline:
            return "addplayer.auth.offline".localized()
        }
    }
}

extension AccountAuthType {
    /// The SF Symbol name and rendering mode for each authentication type.
    var symbol: (name: String, mode: SymbolRenderingMode) {
        switch self {
        case .premium:
            return ("person.crop.circle.badge.plus", .multicolor)
        case .yggdrasil:
            return ("person.crop.circle.badge.questionmark", .multicolor)
        case .offline:
            return ("person.crop.circle.badge.exclamationmark", .multicolor)
        }
    }
}
