import SwiftUI

struct AddPlayerSheetView: View {
    @Binding var playerName: String
    @Binding var isPlayerNameValid: Bool
    var onAdd: () -> Void
    var onCancel: () -> Void
    var onLogin: (MinecraftProfileResponse) -> Void

    enum PlayerProfile {
        case minecraft(MinecraftProfileResponse)
    }

    @ObservedObject var playerListViewModel: PlayerListViewModel

    @State private var isPremium: Bool = false
    @State private var authenticatedProfile: MinecraftProfileResponse?
    @StateObject private var authService = MinecraftAuthService.shared

    @Environment(\.openURL)
    private var openURL
    @State private var selectedAuthType: AccountAuthType = .premium
    @FocusState private var isTextFieldFocused: Bool
    @State private var showErrorPopover: Bool = false

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
                        onCancel()
                    }
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
                    } else {
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
        // 可以根据需要添加其他校验规则
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

// Assuming AccountAuthType is defined as:
enum AccountAuthType: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    case offline
    case premium

    var displayName: String {
        switch self {
        case .premium:
            return "addplayer.auth.microsoft".localized()
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
        default:
            return ("person.crop.circle.badge.minus", .multicolor)
        }
    }
}
