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
    /// 三方密码登录表单状态(登录按钮在 footer,状态提升至此共享)
    @State private var yggLoginUsername = ""
    @State private var yggLoginPassword = ""
    @State private var yggRememberPassword = false

    /// 标题栏选择器的固定文本宽度:认证方式 40,皮肤站 80(超长尾部省略)。
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
                        // 三方:认证方式选择器右侧依次为皮肤站选择器与添加入口
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
                            // 密码型自定义服务器:登录按钮与 OAuth「开始登录」同位
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
                                onYggdrasilLogin?(profile)
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

    // MARK: - 三方皮肤站选择(标题栏全局入口)

    /// 浏览器授权 / 令牌交换进行中不允许切换,避免悬空的 OAuth 回调。
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
            // 宽度与认证方式选择器的文本同宽(两侧菜单外观一致,控件即等宽),
            // 超长站点名尾部省略;框架打在标签文本上,Menu 控件会贴合标签尺寸
            Text(container.system.yggdrasilAuthService.currentServer?.name
                ?? "yggdrasil.server.please_select".localized())
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: serverPickerTextWidth, alignment: .leading)
        }
        .disabled(yggdrasilAuthInFlight)
    }

    /// 纯图标添加入口,悬停显示说明。
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

    /// 切换皮肤站:清空进行中的登录状态(令牌绑定在旧服务器上,不可复用)。
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
