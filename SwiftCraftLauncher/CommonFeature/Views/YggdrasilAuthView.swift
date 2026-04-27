import SwiftUI

struct YggdrasilAuthView: View {
    @StateObject private var authService: YggdrasilAuthService
    @StateObject private var viewModel = YggdrasilAuthViewModel()
    @StateObject private var playerSettings: PlayerSettingsManager
    var onLoginSuccess: ((YggdrasilProfile) -> Void)?

    private let servers = YggdrasilServerPresets.servers

    init(
        authService: YggdrasilAuthService = AppServices.yggdrasilAuthService,
        playerSettings: PlayerSettingsManager = AppServices.playerSettingsManager,
        onLoginSuccess: ((YggdrasilProfile) -> Void)? = nil
    ) {
        // 注入通用解析器 Provider（幂等）
        CommonYggdrasilProfileParsersConfigurator.bootstrap()
        _authService = StateObject(wrappedValue: authService)
        _playerSettings = StateObject(wrappedValue: playerSettings)
        self.onLoginSuccess = onLoginSuccess
    }

    var body: some View {
        VStack {
            if authService.currentServer == nil {
                serverPickerSection
            } else {
                authStateSection
            }
        }
        .padding(.vertical, 20)
        .onChange(of: viewModel.selectedOption) { _, newValue in
            viewModel.onSelectedOptionChanged(newValue, authService: authService)
        }
        .onAppear {
            guard viewModel.selectedOption == nil else { return }
            let presetBaseURL = playerSettings.defaultYggdrasilServerBaseURL
            guard !presetBaseURL.isEmpty else { return }
            if let preset = servers.first(where: { $0.baseURL.absoluteString == presetBaseURL }) {
                viewModel.selectedOption = preset
            }
        }
        .onDisappear {
            viewModel.onDisappear(authService: authService)
        }
    }

    private var serverPickerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("yggdrasil.server.select".localized())
                .font(.headline)
            Picker("yggdrasil.server.picker".localized(), selection: $viewModel.selectedOption) {
                Text("yggdrasil.server.please_select".localized())
                    .tag(nil as YggdrasilServerConfig?)

                ForEach(servers, id: \.self) { server in
                    Text(server.name ?? server.baseURL.absoluteString).tag(server as YggdrasilServerConfig?)
                }
            }
            .pickerStyle(.menu)
        }
    }

    @ViewBuilder private var authStateSection: some View {
        switch authService.authState {
        case .idle:
            notAuthenticatedView
        case .waitingForBrowser:
            waitingForBrowserView
        case .exchangingCode:
            exchangingCodeView
        case .authenticated(let profile):
            authenticatedView(profile: profile)
        case .failed(let message):
            failedView(message: message)
        }
    }

    private var notAuthenticatedView: some View {
        statusView(
            systemImage: "person.crop.circle.badge.questionmark",
            titleKey: "yggdrasil.auth.ready",
            subtitleKey: "yggdrasil.auth.ready.subtitle",
            subtitleFont: .caption
        )
    }

    private var waitingForBrowserView: some View {
        statusView(
            systemImage: "person.crop.circle.badge.clock",
            titleKey: "yggdrasil.auth.waiting_browser",
            subtitleKey: "yggdrasil.auth.waiting_browser.subtitle",
            subtitleFont: .subheadline
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
        let profiles = authService.authenticatedProfiles.isEmpty ? [profile] : authService.authenticatedProfiles
        let selection = Binding<String>(
            get: { profile.id },
            set: { newId in
                viewModel.selectAuthenticatedProfile(id: newId, authService: authService)
            }
        )

        return VStack(spacing: 20) {
            profileAvatarView(for: profile)
            VStack(spacing: 8) {
                profileNameSection(
                    profiles: profiles,
                    selection: selection,
                    currentProfile: profile
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
        subtitleFont: Font
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
                    .frame(width: 80, height: 80)
            )
        }

        return AnyView(
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                )
        )
    }

    private func profileNameSection(
        profiles: [YggdrasilProfile],
        selection: Binding<String>,
        currentProfile: YggdrasilProfile
    ) -> some View {
        Group {
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
