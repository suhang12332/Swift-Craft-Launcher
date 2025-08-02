import SwiftUI

struct AddPlayerSheetView: View {
    @Binding var playerName: String
    @Binding var isPlayerNameValid: Bool
    var onAdd: () -> Void
    var onCancel: () -> Void
    var onLogin: (MinecraftProfileResponse) -> Void
    @ObservedObject var playerListViewModel: PlayerListViewModel
    @State private var isPremium: Bool = false
    @State private var authenticatedProfile: MinecraftProfileResponse?
    @StateObject private var authService = MinecraftAuthService.shared
    @Environment(\.openURL) private var openURL
    var body: some View {
        CommonSheetView(
            header: {
                HStack {
                    Text((isPremium ? "addplayer.title.online" : "addplayer.title.offline").localized())
                        .font(.headline)
                    Spacer()
                    Toggle(isPremium ? "addplayer.auth.microsoft".localized() : "addplayer.auth.offline".localized(), isOn: $isPremium)
                        .toggleStyle(SwitchToggleStyle())
                        .font(.headline)
                        .controlSize(.mini).disabled(authService.isLoading)
                }
            },
            body: {
                if isPremium {
                    MinecraftAuthView(onLoginSuccess: onLogin)
                } else {
                    VStack(alignment: .leading) {
                        playerInfoSection
                            .padding(.bottom, 10)
                        playerNameInputSection
                    }
                }
            },
            footer: {
                HStack {
                    Button("common.cancel".localized(), action: {
                        authService.isLoading = false
                        onCancel()
                    })
                    Spacer()
                    if isPremium {
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
                        Button("addplayer.create".localized(), action: {
                            authService.isLoading = false
                            onAdd()
                        })
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
            TextField("addplayer.name.placeholder".localized(), text: $playerName)
                .textFieldStyle(.roundedBorder)
                .onChange(of: playerName) { _, newValue in
                    checkPlayerName(newValue)
                }
        }
    }

    // 校验错误提示
    private var playerNameError: String {
        let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
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
        isPlayerNameValid = !trimmedName.isEmpty && !playerListViewModel.playerExists(name: trimmedName)
    }
} 

