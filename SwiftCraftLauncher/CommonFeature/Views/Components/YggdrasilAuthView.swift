//
//  YggdrasilAuthView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A view for authenticating with Yggdrasil-compatible Minecraft servers.
///
/// 内置预设走 OAuth 浏览器授权;用户添加的自定义皮肤站使用
/// 用户名密码(classic authserver)登录。
struct YggdrasilAuthView: View {
    @Environment(DIContainer.self)
    private var container
    @State private var viewModel = YggdrasilAuthViewModel()
    var onLoginSuccess: ((YggdrasilProfile) -> Void)?

    /// 密码登录表单状态(视图本地,不落盘;记住的密码由统一凭据存储接管)。
    @State private var loginUsername = ""
    @State private var loginPassword = ""
    @State private var rememberPassword = false
    @State private var showCustomServerSheet = false

    init(
        onLoginSuccess: ((YggdrasilProfile) -> Void)? = nil,
    ) {
        CommonYggdrasilProfileParsersConfigurator.bootstrap()
        self.onLoginSuccess = onLoginSuccess
    }

    /// 服务器列表来自统一注册表(预设 ∪ 自定义),sheet 关闭后自动刷新。
    private var servers: [YggdrasilServerConfig] {
        YggdrasilServerRegistry.allServers
    }

    private var selectedServerIsPassword: Bool {
        container.system.yggdrasilAuthService.currentServer?.isPasswordLogin == true
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack {
            if container.system.yggdrasilAuthService.currentServer == nil {
                serverPickerSection
            } else {
                authStateSection
                    .padding(.vertical, 20)
            }
        }
        .onChange(of: viewModel.selectedOption) { _, newValue in
            loginUsername = ""
            loginPassword = ""
            rememberPassword = false
            viewModel.onSelectedOptionChanged(newValue, authService: container.system.yggdrasilAuthService)
        }
        .onAppear {
            guard viewModel.selectedOption == nil else { return }
            let presetBaseURL = container.ui.playerSettingsManager.defaultYggdrasilServerBaseURL
            guard !presetBaseURL.isEmpty else { return }
            if let preset = servers.first(where: { $0.baseURL.absoluteString == presetBaseURL }) {
                viewModel.selectedOption = preset
            }
        }
        .onDisappear {
            viewModel.onDisappear(authService: container.system.yggdrasilAuthService)
        }
        .sheet(isPresented: $showCustomServerSheet) {
            CustomYggdrasilServerSheet()
        }
    }

    // MARK: - 服务器选择

    private var serverPickerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("yggdrasil.server.select".localized())
                .font(.headline)
                .padding(.bottom, 4)

            Text("yggdrasil.server.select.description".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 10)

            Picker("yggdrasil.server.picker".localized(), selection: $viewModel.selectedOption) {
                Text("yggdrasil.server.please_select".localized())
                    .tag(nil as YggdrasilServerConfig?)

                ForEach(servers, id: \.self) { server in
                    Text(server.name).tag(server as YggdrasilServerConfig?)
                }
            }
            .pickerStyle(.menu)

            Button {
                showCustomServerSheet = true
            } label: {
                Label("yggdrasil.custom.add".localized(), systemImage: "plus.circle")
                    .font(.subheadline)
            }
            .buttonStyle(.link)
            .padding(.top, 6)
        }
    }

    // MARK: - 认证状态

    @ViewBuilder private var authStateSection: some View {
        switch container.system.yggdrasilAuthService.authState {
        case .idle:
            if selectedServerIsPassword {
                passwordLoginForm
            } else {
                notAuthenticatedView
            }
        case .waitingForBrowser:
            waitingForBrowserView
        case .processing:
            exchangingCodeView
        case let .authenticated(profile):
            authenticatedView(profile: profile)
        case let .error(message):
            failedView(message: message)
        }
    }

    // MARK: - 密码登录表单

    private var passwordLoginForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            let server = container.system.yggdrasilAuthService.currentServer
            let usernameKey = server?.nonEmailLoginHintAvailable == true
                ? "yggdrasil.password.username_non_email" : "yggdrasil.password.username"

            TextField(usernameKey.localized(), text: $loginUsername)
                .textFieldStyle(.roundedBorder)
                .textContentType(.username)

            SecureField("yggdrasil.password.password".localized(), text: $loginPassword)
                .textFieldStyle(.roundedBorder)
                .textContentType(.password)

            Toggle("yggdrasil.password.remember".localized(), isOn: $rememberPassword)

            Text("yggdrasil.password.remember.hint".localized())
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                let username = loginUsername
                let password = loginPassword
                let remember = rememberPassword
                Task {
                    await container.system.yggdrasilAuthService.startPasswordAuthentication(
                        username: username,
                        password: password,
                        rememberPassword: remember,
                    )
                }
            } label: {
                Text("yggdrasil.password.login".localized())
            }
            .buttonStyle(.borderedProminent)
            .disabled(loginUsername.isEmpty || loginPassword.isEmpty)
        }
        .padding(.horizontal, 8)
    }

    private var notAuthenticatedView: some View {
        statusView(
            systemImage: "person.crop.circle.badge.questionmark",
            titleKey: "yggdrasil.auth.ready",
            subtitleKey: "yggdrasil.auth.ready.subtitle",
            subtitleFont: .caption,
        )
    }

    private var waitingForBrowserView: some View {
        statusView(
            systemImage: "person.crop.circle.badge.clock",
            titleKey: "yggdrasil.auth.waiting_browser",
            subtitleKey: "yggdrasil.auth.waiting_browser.subtitle",
            subtitleFont: .subheadline,
        )
    }

    private var exchangingCodeView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.small)
            Text("yggdrasil.auth.processing".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func authenticatedView(profile: YggdrasilProfile) -> some View {
        let profiles = container.system.yggdrasilAuthService.authenticatedProfiles.isEmpty ? [profile] : container.system.yggdrasilAuthService.authenticatedProfiles
        let selection = Binding<String>(
            get: { profile.id },
            set: { newId in
                viewModel.selectAuthenticatedProfile(id: newId, authService: container.system.yggdrasilAuthService)
            },
        )

        return VStack(spacing: 20) {
            profileAvatarView(for: profile)
            VStack(spacing: 8) {
                profileNameSection(
                    profiles: profiles,
                    selection: selection,
                    currentProfile: profile,
                )
                Text(String(format: "minecraft.auth.uuid".localized(), profile.id))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
            Text("minecraft.auth.confirm_login".localized())
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func statusView(
        systemImage: String,
        titleKey: String,
        subtitleKey: String,
        subtitleFont: Font,
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 46))
                .symbolRenderingMode(.multicolor)
                .symbolVariant(.none)
                .foregroundColor(.secondary)
            Text(titleKey.localized())
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(subtitleKey.localized())
                .font(subtitleFont)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func profileAvatarView(for profile: YggdrasilProfile) -> some View {
        if let skinUrl = profile.skins.first?.url, !skinUrl.isEmpty {
            return AnyView(
                MinecraftSkinUtils(type: .url, src: skinUrl.httpToHttps())
                    .frame(width: 80, height: 80),
            )
        }

        return AnyView(
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.largeTitle)
                        .foregroundColor(.gray),
                ),
        )
    }

    @ViewBuilder
    private func profileNameSection(
        profiles: [YggdrasilProfile],
        selection: Binding<String>,
        currentProfile: YggdrasilProfile,
    ) -> some View {
        if profiles.count > 1 {
            Picker("", selection: selection) {
                ForEach(profiles, id: \.id) { p in
                    Text(p.name).tag(p.id)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .labelsHidden()
        } else {
            Text(currentProfile.name)
                .font(.headline)
        }
    }

    private func failedView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)
            Text("minecraft.auth.failed".localized())
                .font(.headline)
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

/// 是否展示"支持角色名登录"提示(自定义服务器元数据)。
private extension YggdrasilServerConfig {
    var nonEmailLoginHintAvailable: Bool {
        guard let apiRootString = apiRoot?.absoluteString else { return false }
        return CustomYggdrasilServerStore.load()
            .first { $0.apiRoot == apiRootString }?
            .nonEmailLogin ?? false
    }
}
