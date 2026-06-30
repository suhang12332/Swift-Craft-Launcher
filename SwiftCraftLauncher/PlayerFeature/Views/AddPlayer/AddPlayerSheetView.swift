//
//  AddPlayerSheetView.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Provides the UI for adding a new player via Microsoft, Yggdrasil, or offline authentication.
struct AddPlayerSheetView: View {
    @Binding var playerName: String
    @Binding var isPlayerNameValid: Bool
    var onAdd: () -> Void
    var onCancel: () -> Void
    var onLogin: (MinecraftProfileResponse) -> Void
    var onYggdrasilLogin: ((YggdrasilProfile) -> Void)?

    enum PlayerProfile {
        case minecraft(MinecraftProfileResponse)
    }

    @ObservedObject var playerListViewModel: PlayerListViewModel

    @State private var isPremium: Bool = false
    @State private var authenticatedProfile: MinecraftProfileResponse?
    @StateObject private var authService: MinecraftAuthService
    @StateObject private var yggdrasilAuthService: YggdrasilAuthService
    @StateObject private var playerSettings: PlayerSettingsManager
    @StateObject private var viewModel = AddPlayerSheetViewModel()

    @Environment(\.openURL)
    private var openURL
    @FocusState private var isTextFieldFocused: Bool
    @State private var showErrorPopover: Bool = false

    init(
        playerName: Binding<String>,
        isPlayerNameValid: Binding<Bool>,
        onAdd: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onLogin: @escaping (MinecraftProfileResponse) -> Void,
        onYggdrasilLogin: ((YggdrasilProfile) -> Void)? = nil,
        playerListViewModel: PlayerListViewModel,
        authService: MinecraftAuthService = AppServices.minecraftAuthService,
        yggdrasilAuthService: YggdrasilAuthService = AppServices.yggdrasilAuthService,
        playerSettings: PlayerSettingsManager = AppServices.playerSettingsManager,
    ) {
        _playerName = playerName
        _isPlayerNameValid = isPlayerNameValid
        self.onAdd = onAdd
        self.onCancel = onCancel
        self.onLogin = onLogin
        self.onYggdrasilLogin = onYggdrasilLogin
        self.playerListViewModel = playerListViewModel
        _authService = StateObject(wrappedValue: authService)
        _yggdrasilAuthService = StateObject(wrappedValue: yggdrasilAuthService)
        _playerSettings = StateObject(wrappedValue: playerSettings)
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
                       let serverName = yggdrasilAuthService.currentServer?.name {
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
                    VStack(alignment: .leading) {
                        playerInfoSection
                            .padding(.bottom, 10)
                        playerNameInputSection
                    }
                }
            },
            footer: {
                HStack {
                    Button(
                        "common.cancel".localized(),
                    ) {
                        authService.isLoading = false
                        yggdrasilAuthService.logout()
                        onCancel()
                    }
                    Spacer()
                    if viewModel.selectedAuthType == .premium {
                        switch authService.authState {
                        case .notAuthenticated:
                            Button("addplayer.auth.start_login".localized()) {
                                Task {
                                    await viewModel.startPremiumAuthentication(authService: authService)
                                }
                            }
                            .keyboardShortcut(.defaultAction)

                        case let .authenticated(profile):
                            Button("addplayer.auth.add".localized()) {
                                onLogin(profile)
                            }
                            .keyboardShortcut(.defaultAction)

                        case .error:
                            Button("addplayer.auth.retry".localized()) {
                                Task {
                                    await viewModel.startPremiumAuthentication(authService: authService)
                                }
                            }
                            .keyboardShortcut(.defaultAction)

                        default:
                            ProgressView().controlSize(.small)
                        }
                    } else if viewModel.selectedAuthType == .yggdrasil {
                        switch yggdrasilAuthService.authState {
                        case .idle, .failed:
                            Button("addplayer.auth.start_login".localized()) {
                                Task {
                                    await viewModel.startYggdrasilAuthentication(
                                        yggdrasilAuthService: yggdrasilAuthService,
                                    )
                                }
                            }
                            .keyboardShortcut(.defaultAction)
                            .disabled(yggdrasilAuthService.currentServer == nil)
                        case let .authenticated(profile):
                            Button("addplayer.auth.add".localized()) {
                                onYggdrasilLogin?(profile)
                            }
                            .keyboardShortcut(.defaultAction)
                        case .waitingForBrowser, .exchangingCode:
                            ProgressView().controlSize(.small)
                        }
                    } else {
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
                            authService.isLoading = false
                            onAdd()
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
        authService.isLoading = false
        isTextFieldFocused = false
        showErrorPopover = false
        yggdrasilAuthService.logout()
        viewModel.reset()
    }

    private var playerInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("addplayer.info.title".localized())
                .font(.headline).padding(.bottom, 4)
            Text("addplayer.info.line1".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("addplayer.info.line2".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("addplayer.info.line3".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("addplayer.info.line4".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var playerNameInputSection: some View {
        VStack(alignment: .leading) {
            Text("addplayer.name.label".localized())
                .font(.headline.bold())
            TextField(
                "addplayer.name.placeholder".localized(),
                text: $playerName,
            )
            .textFieldStyle(.roundedBorder)
            .focused($isTextFieldFocused)
            .focusEffectDisabled()
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(borderColor, lineWidth: 2),
            )
            .popover(isPresented: $showErrorPopover, arrowEdge: .trailing) {
                if let errorMessage = playerNameError {
                    Text(errorMessage)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }
            .onChange(of: playerName) { _, newValue in
                checkPlayerName(newValue)
            }
        }
    }

    private var borderColor: Color {
        if isTextFieldFocused {
            return .blue
        } else {
            return .clear
        }
    }

    private var playerNameError: String? {
        let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        if playerListViewModel.playerExists(name: trimmedName) {
            return "addplayer.name.error.duplicate".localized()
        }
        return nil
    }

    private func checkPlayerName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasError = playerNameError != nil
        isPlayerNameValid = !trimmedName.isEmpty && !hasError
        showErrorPopover = hasError
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
