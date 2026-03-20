import SwiftUI

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
    @StateObject private var authService = MinecraftAuthService.shared
    @StateObject private var yggdrasilAuthService = YggdrasilAuthService.shared
    @StateObject private var playerSettings = PlayerSettingsManager.shared
    @StateObject private var viewModel = AddPlayerSheetViewModel()

    @Environment(\.openURL)
    private var openURL
    @FocusState private var isTextFieldFocused: Bool
    @State private var showErrorPopover: Bool = false

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
                            .frame(height: 20.5) // 设置固定高度，与 Picker 保持一致
                            .padding(.trailing, 10)
                    } else {
                        CommonMenuPicker(
                            selection: $viewModel.selectedAuthType,
                            hidesLabel: true
                        ) {
                            Text("")
                        } content: {
                            ForEach(viewModel.availableAuthTypes) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .labelStyle(.titleOnly)
                        .fixedSize()
                    }
                }
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
                        "common.cancel".localized()
                    ) {
                        authService.isLoading = false
                        yggdrasilAuthService.logout()
                        onCancel()
                    }
                    Spacer()
                    if viewModel.selectedAuthType == .premium {
                        // 根据认证状态显示不同的按钮
                        switch authService.authState {
                        case .notAuthenticated:
                            Button("addplayer.auth.start_login".localized()) {
                                Task {
                                    await viewModel.startPremiumAuthentication(authService: authService)
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
                                        yggdrasilAuthService: yggdrasilAuthService
                                    )
                                }
                            }
                            .keyboardShortcut(.defaultAction)
                            .disabled(yggdrasilAuthService.currentServer == nil)
                        case .authenticated(let profile):
                            Button("addplayer.auth.add".localized()) {
                                onYggdrasilLogin?(profile)
                            }
                            .keyboardShortcut(.defaultAction)
                        case .waitingForBrowser, .exchangingCode:
                            ProgressView().controlSize(.small)
                        }
                    } else {
                        Button(
                            "addplayer.purchase.minecraft".localized()
                        ) {
                            openURL(URLConfig.Store.minecraftPurchase)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)

                        Button(
                            "addplayer.create".localized()
                        ) {
                            authService.isLoading = false
                            onAdd()
                        }
                        .disabled(!isPlayerNameValid)
                        .keyboardShortcut(.defaultAction)
                    }
                }
            }
        )
        .task {
            // 检查标记
            await viewModel.checkPremiumAccountFlag()
        }
        .onDisappear {
            // 页面关闭后清除所有数据
            clearAllData()
        }
    }

    // MARK: - 清除数据
    /// 清除页面所有数据
    private func clearAllData() {
        // 清理玩家名称
        playerName = ""
        isPlayerNameValid = false
        // 清理认证状态
        authenticatedProfile = nil
        isPremium = false
        // 重置认证服务状态
        authService.isLoading = false
        // 重置焦点状态
        isTextFieldFocused = false
        showErrorPopover = false
        yggdrasilAuthService.logout()
        viewModel.reset()
    }

    // 说明区
    private var playerInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("addplayer.info.title".localized())
                .font(.headline) .padding(.bottom, 4)
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
            Text("addplayer.name.label".localized())
                .font(.headline.bold())
            TextField(
                "addplayer.name.placeholder".localized(),
                text: $playerName
            )
            .textFieldStyle(.roundedBorder)
            .focused($isTextFieldFocused)
            .focusEffectDisabled()
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(borderColor, lineWidth: 2)
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

    // 根据输入状态和焦点状态决定边框颜色
    private var borderColor: Color {
        if isTextFieldFocused {
            return .blue
        } else {
            return .clear
        }
    }

    // 获取错误信息（仅在不合法时，不包括空字符串）
    private var playerNameError: String? {
        let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        if playerListViewModel.playerExists(name: trimmedName) {
            return "addplayer.name.error.duplicate".localized()
        }
        // 可添加其他校验规则
        return nil
    }

    private func checkPlayerName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // 基于 playerNameError 和是否为空来设置状态，避免重复检查
        let hasError = playerNameError != nil
        isPlayerNameValid = !trimmedName.isEmpty && !hasError
        showErrorPopover = hasError
    }
}

enum AccountAuthType: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    case premium
    case yggdrasil
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
    var symbol: (name: String, mode: SymbolRenderingMode) {
        switch self {
        case .premium:
            return ("person.crop.circle.badge.plus", .multicolor)
        case .yggdrasil:
            return ("person.crop.circle.badge.questionmark.fill", .multicolor)
        case .offline:
            return ("person.crop.circle.badge.minus", .multicolor)
        }
    }
}
