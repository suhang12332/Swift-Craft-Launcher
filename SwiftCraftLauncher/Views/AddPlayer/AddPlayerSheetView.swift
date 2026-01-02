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

    // 标记检查状态
    @State private var isCheckingFlag: Bool = true  // 初始为true，进入页面时直接显示loading
    // IP检查结果（仅在列表中没有正版账户且没有标记时使用）
    @State private var isForeignIP: Bool = false

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
                    if isCheckingFlag {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 8)
                    } else {
                        Picker("", selection: $selectedAuthType) {
                            ForEach(availableAuthTypes) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.menu)  // 用下拉菜单样式
                        .labelStyle(.titleOnly)
                        .fixedSize()
                    }
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
            await checkPremiumAccountFlag()
        }
        .onDisappear {
            // 页面关闭后清除所有数据
            clearAllData()
        }
    }

    // MARK: - 检查逻辑

    /// 检查是否可以添加离线账户
    private func canAddOfflineAccount() -> Bool {
        // 检查标记：如果曾经添加过正版账户（标记存在），则可以添加离线账户
        let flagManager = PremiumAccountFlagManager.shared
        if flagManager.hasAddedPremiumAccount() {
            return true
        }

        // 如果没有标记，需要检查IP地理位置
        // 如果是国外IP，不允许添加离线账户
        // 如果是国内IP（或检查失败），允许添加离线账户
        return !isForeignIP
    }

    /// 检查正版账户标记
    private func checkPremiumAccountFlag() async {
        // 检查标记
        let flagManager = PremiumAccountFlagManager.shared
        let hasFlag = flagManager.hasAddedPremiumAccount()
        // 如果没有标记，同步检查IP地理位置
        if !hasFlag {
            // loading状态已经显示，继续显示直到IP检查完成
            let locationService = IPLocationService.shared
            let foreign = await locationService.isForeignIP()

            await MainActor.run {
                isForeignIP = foreign
                isCheckingFlag = false

                // 确保 selectedAuthType 在可用选项中
                if !availableAuthTypes.contains(selectedAuthType) {
                    selectedAuthType = .premium
                }
            }
        } else {
            // 如果有标记，允许添加离线账户
            await MainActor.run {
                isCheckingFlag = false
            }
        }
    }

    /// 获取可用的认证类型列表
    private var availableAuthTypes: [AccountAuthType] {
        // 如果可以添加离线账户，显示所有选项
        if canAddOfflineAccount() {
            return AccountAuthType.allCases
        }

        // 如果是国外IP且列表中没有正版账户，只显示正版选项
        return [.premium]
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
        // 重置认证类型
        selectedAuthType = .premium
        // 重置标记检查状态
        isCheckingFlag = true
        // 重置IP检查结果
        isForeignIP = false
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
