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
    @Binding var playerName: String
    @Binding var isPlayerNameValid: Bool
    var onAdd: () -> Void
    var onCancel: () -> Void
    var onLogin: (MinecraftProfileResponse) -> Void
    var onYggdrasilLogin: ((YggdrasilProfile) -> Void)?

    enum PlayerProfile {
        case minecraft(MinecraftProfileResponse)
    }

    var playerListViewModel: PlayerListViewModel

    @State private var isPremium: Bool = false
    @State private var authenticatedProfile: MinecraftProfileResponse?
    @State private var viewModel = AddPlayerSheetViewModel()

    @Environment(\.openURL)
    private var openURL
    @State private var showErrorPopover: Bool = false
    @State private var showCustomServerSheet: Bool = false
    /// Third-party password form state, lifted here because the footer hosts the login button.
    @State private var yggLoginUsername = ""
    @State private var yggLoginPassword = ""
    @State private var yggRememberPassword = false

    /// Fixed label widths of the title bar pickers; long server names are truncated.
    private let authTypePickerTextWidth: CGFloat = 40
    private let serverPickerTextWidth: CGFloat = 80

    init(
        playerName: Binding<String>,
        isPlayerNameValid: Binding<Bool>,
        onAdd: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onLogin: @escaping (MinecraftProfileResponse) -> Void,
        onYggdrasilLogin: ((YggdrasilProfile) -> Void)? = nil,
        playerListViewModel: PlayerListViewModel,
    ) {
        _playerName = playerName
        _isPlayerNameValid = isPlayerNameValid
        self.onAdd = onAdd
        self.onCancel = onCancel
        self.onLogin = onLogin
        self.onYggdrasilLogin = onYggdrasilLogin
        self.playerListViewModel = playerListViewModel
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
                    Spacer()
                    if viewModel.isCheckingFlag {
                        ProgressView()
                            .controlSize(.small)
                            .frame(height: 20.5)
                            .padding(.trailing, 10)
                    } else if viewModel.selectedAuthType == .yggdrasil {
                        // Third-party: auth type picker, then server picker and the add-server button.
                        HStack(spacing: 6) {
                            authTypePicker
                            yggdrasilServerMenu
                            addCustomServerButton
                        }
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
                    YggdrasilAuthView(
                        onLoginSuccess: onYggdrasilLogin,
                        loginUsername: $yggLoginUsername,
                        loginPassword: $yggLoginPassword,
                        rememberPassword: $yggRememberPassword,
                    )
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
                        container.system.minecraftAuthService.isLoading = false
                        container.system.yggdrasilAuthService.logout()
                        onCancel()
                    }
                    Spacer()
                    if viewModel.selectedAuthType == .premium {
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
                    } else if viewModel.selectedAuthType == .yggdrasil {
                        switch container.system.yggdrasilAuthService.authState {
                        case .idle, .error:
                            // Password servers show their login button where OAuth shows "Start login".
                            if container.system.yggdrasilAuthService.currentServer?.isPasswordLogin == true {
                                Button("yggdrasil.password.login".localized()) {
                                    let username = yggLoginUsername
                                    let password = yggLoginPassword
                                    let remember = yggRememberPassword
                                    Task {
                                        await container.system.yggdrasilAuthService.startPasswordAuthentication(
                                            username: username,
                                            password: password,
                                            rememberPassword: remember,
                                        )
                                    }
                                }
                                .keyboardShortcut(.defaultAction)
                                .disabled(yggLoginUsername.isEmpty || yggLoginPassword.isEmpty)
                            } else {
                                Button("addplayer.auth.start_login".localized()) {
                                    Task {
                                        await viewModel.startYggdrasilAuthentication(
                                            yggdrasilAuthService: container.system.yggdrasilAuthService,
                                        )
                                    }
                                }
                                .keyboardShortcut(.defaultAction)
                                .disabled(container.system.yggdrasilAuthService.currentServer == nil)
                            }
                        case let .authenticated(profile):
                            Button("addplayer.auth.add".localized()) {
                                Task {
                                    let authService = container.system.yggdrasilAuthService
                                    if let ready = await authService.prepareProfileForAdding(profile) {
                                        onYggdrasilLogin?(ready)
                                    }
                                }
                            }
                            .keyboardShortcut(.defaultAction)
                        case .waitingForBrowser, .processing:
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
                            container.system.minecraftAuthService.isLoading = false
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
        .sheet(isPresented: $showCustomServerSheet) {
            CustomYggdrasilServerSheet()
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
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: authTypePickerTextWidth)
        }
        .fixedSize()
    }

    /// Switching is blocked during browser authorization or token exchange to avoid dangling callbacks.
    private var yggdrasilAuthInFlight: Bool {
        switch container.system.yggdrasilAuthService.authState {
        case .waitingForBrowser, .processing:
            return true
        default:
            return false
        }
    }

    private var yggdrasilServerMenu: some View {
        Menu {
            ForEach(YggdrasilServerRegistry.allServers, id: \.self) { server in
                Button {
                    selectYggdrasilServer(server)
                } label: {
                    if container.system.yggdrasilAuthService.currentServer == server {
                        Label(server.name, systemImage: "checkmark")
                    } else {
                        Text(server.name)
                    }
                }
            }
        } label: {
            // Same label width as the auth type picker so both menus look alike; long
            // names are truncated. The frame is applied to the label so the Menu hugs it.
            Text(container.system.yggdrasilAuthService.currentServer?.name
                ?? "yggdrasil.server.please_select".localized())
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: serverPickerTextWidth, alignment: .leading)
        }
        .disabled(yggdrasilAuthInFlight)
    }

    /// Icon-only add button with a hover tooltip.
    private var addCustomServerButton: some View {
        Button {
            showCustomServerSheet = true
        } label: {
            Image(systemName: "plus.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .disabled(yggdrasilAuthInFlight)
        .help("yggdrasil.custom.add".localized())
    }

    /// Switches the skin site and clears any in-flight login (tokens belong to the old server).
    private func selectYggdrasilServer(_ server: YggdrasilServerConfig) {
        let authService = container.system.yggdrasilAuthService
        guard authService.currentServer != server else { return }

        authService.logout()
        authService.setServer(server)
        yggLoginUsername = ""
        yggLoginPassword = ""
        yggRememberPassword = false
    }

    /// Clears all data and resets authentication state when the sheet is dismissed.
    private func clearAllData() {
        playerName = ""
        isPlayerNameValid = false
        authenticatedProfile = nil
        isPremium = false
        container.system.minecraftAuthService.isLoading = false
        showErrorPopover = false
        container.system.yggdrasilAuthService.logout()
        // Also clear the password form: closing the sheet discards the entered credentials.
        yggLoginUsername = ""
        yggLoginPassword = ""
        yggRememberPassword = false
        viewModel.reset()
    }

    private var playerInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("addplayer.info.title".localized())
                .font(.headline)
                .padding(.bottom, 4)

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
                .font(.headline)
            TextField(
                "addplayer.name.placeholder".localized(),
                text: $playerName,
            )
            .textFieldStyle(.roundedBorder)
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
