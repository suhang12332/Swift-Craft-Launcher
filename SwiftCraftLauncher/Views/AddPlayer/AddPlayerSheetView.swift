import SwiftUI

struct AddPlayerSheetView: View {
    @Binding var playerName: String
    @Binding var isPlayerNameValid: Bool
    var onAdd: () -> Void
    var onCancel: () -> Void
    var onLogin: (MinecraftProfileResponse) -> Void
    var onYggLogin: (YggdrasilProfileResponse) -> Void
    enum PlayerProfile {
        case minecraft(MinecraftProfileResponse)
        case yggdrasil(YggdrasilProfileResponse)
    }
    @ObservedObject var playerListViewModel: PlayerListViewModel
    @State private var isPremium: Bool = false
    @State private var authenticatedProfile: MinecraftProfileResponse?
    @StateObject private var authService = MinecraftAuthService.shared
    @StateObject private var yggdrasilAuthService = YggdrasilAuthService.shared
    @Environment(\.openURL) private var openURL
    @State private var selectedAuthType: AccountAuthType = .offline

    var body: some View {
        CommonSheetView(
            header: {
                HStack {
                    Text("addplayer.title".localized())
                        .font(.headline)
                    Image(systemName: selectedAuthType.symbol.name)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(selectedAuthType.symbol.mode)
                        .symbolVariant(.none)
                    Spacer()
                    Picker("", selection: $selectedAuthType) {
                        ForEach(AccountAuthType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)  // 用下拉菜单样式
                    .labelStyle(.titleOnly)
                    .fixedSize()
                }
            },
            body: {
                switch selectedAuthType {
                case .premium:
                    MinecraftAuthView(onLoginSuccess: onLogin)
                case .yggdrasil:
                    YggdrasilAuthView()
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
                        action: {
                            authService.isLoading = false
                            onCancel()
                        }
                    )
                    Spacer()
                    if selectedAuthType == .premium {
                        // 根据认证状态显示不同的按钮
                        switch authService.authState {
                        case .notAuthenticated:
                            Button("addplayer.auth.start_login".localized()) {
                                Task {
                                    await authService.startAuthentication()
                                }
                            }
                            .keyboardShortcut(.defaultAction)

                        case .authenticated(let profile):

                            Button("addplayer.auth.add".localized()) {
                                onLogin(profile)
                            }
                            .keyboardShortcut(.defaultAction)

                        case .error:
                            Button("addplayer.auth.retry".localized()) {
                                Task {
                                    await authService.startAuthentication()
                                }
                            }
                            .keyboardShortcut(.defaultAction)

                        default:
                            ProgressView().controlSize(.small)
                        }
                    } else if selectedAuthType == .yggdrasil {
                        switch yggdrasilAuthService.authState {
                        case .notAuthenticated:
                            Button("addplayer.auth.start_login".localized()) {
                                Task {
                                    await yggdrasilAuthService
                                        .startAuthentication()
                                }
                            }
                            .keyboardShortcut(.defaultAction)
                        case .authenticatedYggdrasil(let profile):
                            Button("addplayer.auth.add".localized()) {
                                onYggLogin(profile)
                            }
                            .keyboardShortcut(.defaultAction)
                        case .error:
                            Button("addplayer.auth.retry".localized()) {
                                Task {
                                    await yggdrasilAuthService
                                        .startAuthentication()
                                }
                            }
                            .keyboardShortcut(.defaultAction)
                        default:
                            ProgressView().controlSize(.small)
                        }
                    } else {
                        Button(
                            "addplayer.create".localized(),
                            action: {
                                authService.isLoading = false
                                onAdd()
                            }
                        )
                        .disabled(!isPlayerNameValid)
                        .keyboardShortcut(.defaultAction)
                    }
                }
            }
        )
        .onAppear {
            // 设置URL打开回调
            authService.openURLHandler = { url in
                openURL(url)
            }
            yggdrasilAuthService.openURLHandler = { url in
                openURL(url)
            }
        }
    }

    // 说明区
    private var playerInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("addplayer.info.title".localized())
                .font(.headline)
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

    // 输入区
    private var playerNameInputSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("addplayer.name.label".localized())
                    .font(.headline.bold())
                Spacer()
                if !isPlayerNameValid {
                    Text(playerNameError)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
            TextField(
                "addplayer.name.placeholder".localized(),
                text: $playerName
            )
            .textFieldStyle(.roundedBorder)
            .onChange(of: playerName) { _, newValue in
                checkPlayerName(newValue)
            }
        }
    }

    // 校验错误提示
    private var playerNameError: String {
        let trimmedName = playerName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if trimmedName.isEmpty {
            return "addplayer.name.error.empty".localized()
        }
        if playerListViewModel.playerExists(name: trimmedName) {
            return "addplayer.name.error.duplicate".localized()
        }
        // 长度和字符集校验可根据需要扩展
        return "addplayer.name.error.invalid".localized()
    }

    private func checkPlayerName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        isPlayerNameValid =
            !trimmedName.isEmpty
            && !playerListViewModel.playerExists(name: trimmedName)
    }
}

// Assuming AccountAuthType is defined as:
enum AccountAuthType: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    case offline
    case premium
    case yggdrasil

    var displayName: String {
        switch self {
        case .premium:
            return "addplayer.auth.microsoft".localized()
        case .yggdrasil:
            return "addplayer.auth.yggdrasil".localized()
        default:
            return "addplayer.auth.offline".localized()
        }
    }
}

// 1. 给 AccountAuthType 扩展一个 symbol 配置
extension AccountAuthType {
    var symbol: (name: String, mode: SymbolRenderingMode) {
        switch self {
        case .premium:
            return ("person.crop.circle.badge.plus", .multicolor)
        case .yggdrasil:
            return ("person.crop.circle.badge.questionmark", .multicolor)
        default:
            return ("person.crop.circle.badge.minus", .multicolor)
        }
    }
}
