import SwiftUI

struct YggdrasilAuthView: View {
    @StateObject private var authService = YggdrasilAuthService.shared
    var onLoginSuccess: ((YggdrasilProfileResponse) -> Void)?
    
    @State private var selectedServer: YggdrasilServerInfo?
    
    private var availableServers: [YggdrasilServerInfo] {
        URLConfig.API.YggdrasilServers.servers
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 如果未配置服务器，显示配置界面
            if authService.serverConfig == nil {
                serverConfigView
            } else {
                // 显示认证状态
                switch authService.authState {
                case .notAuthenticated:
                    notAuthenticatedView
                case .waitingForBrowserAuth:
                    waitingForBrowserAuthView
                case .processingAuthCode:
                    processingAuthCodeView
                case .authenticated(let profile):
                    authenticatedView(profile: profile)
                case .error(let message):
                    errorView(message: message)
                }
            }
        }
        .onDisappear {
            clearAllData()
        }
    }
    
    // MARK: - 服务器配置视图
    private var serverConfigView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("yggdrasil.auth.config.title".localized())
                .font(.headline)
            
            // 服务器选择下拉框
            VStack(alignment: .leading, spacing: 4) {
                Text("yggdrasil.auth.config.select_server".localized())
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("", selection: $selectedServer) {
                    Text("yggdrasil.auth.config.select_server.placeholder".localized())
                        .tag(nil as YggdrasilServerInfo?)
                    ForEach(availableServers) { server in
                        Text(server.name)
                            .tag(server as YggdrasilServerInfo?)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedServer) { _, newValue in
                    // 当选择服务器时自动保存配置
                    if let server = newValue {
                        saveConfig(server: server)
                    }
                }
                
                if let server = selectedServer {
                    Text(server.baseURL)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - 未认证状态
    private var notAuthenticatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 46))
                .symbolRenderingMode(.multicolor)
                .symbolVariant(.none)
                .foregroundColor(.secondary)
            Text("yggdrasil.auth.title".localized())
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("yggdrasil.auth.subtitle".localized())
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // 显示当前服务器配置
            if let config = authService.serverConfig {
                VStack(alignment: .leading, spacing: 4) {
                    Text("yggdrasil.auth.current_server".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(config.baseURL)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            Button("yggdrasil.auth.change_server".localized()) {
                authService.serverConfig = nil
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - 等待浏览器授权状态
    private var waitingForBrowserAuthView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.clock")
                .font(.system(size: 46))
                .foregroundColor(.secondary)
            
            Text("yggdrasil.auth.waiting_browser".localized())
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("yggdrasil.auth.waiting_browser.subtitle".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - 处理授权码状态
    private var processingAuthCodeView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.small)
            
            Text("yggdrasil.auth.processing.title".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Text("yggdrasil.auth.processing.subtitle".localized())
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - 认证成功状态
    private func authenticatedView(profile: YggdrasilProfileResponse) -> some View {
        VStack(spacing: 20) {
            // 用户头像
            if let skinUrl = profile.skins.first?.url, !skinUrl.isEmpty {
                MinecraftSkinUtils(type: .url, src: skinUrl.httpToHttps())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(spacing: 8) {
                Text("yggdrasil.auth.success".localized())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Text(profile.name)
                    .font(.headline)
                
                Text(
                    String(
                        format: "yggdrasil.auth.uuid".localized(),
                        profile.id
                    )
                )
                .font(.caption)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
            }
            
            Text("yggdrasil.auth.confirm_login".localized())
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - 错误状态
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("yggdrasil.auth.failed".localized())
                .font(.headline)
                .foregroundColor(.red)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
        }
    }
    
    // MARK: - 辅助方法
    
    private func saveConfig(server: YggdrasilServerInfo) {
        let config = YggdrasilServerConfig(
            baseURL: server.baseURL,
            clientId: server.clientId,
            clientSecret: server.clientSecret,
            redirectURI: server.redirectURI ?? "swift-craft-launcher://auth"
        )
        
        authService.setServerConfig(config)
    }
    
    private func clearAllData() {
        if case .notAuthenticated = authService.authState {
            authService.isLoading = false
        }
    }
}

#Preview {
    YggdrasilAuthView()
}

