import SwiftUI

struct MinecraftAuthView: View {
    @StateObject private var authService = MinecraftAuthService.shared
    var onLoginSuccess: ((MinecraftProfileResponse) -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            // 认证状态显示
            switch authService.authState {
            case .notAuthenticated:
                notAuthenticatedView
                
            case .requestingCode:
                requestingCodeView
                
            case .waitingForUser(let userCode, let verificationUri):
                waitingForUserView(userCode: userCode, verificationUri: verificationUri)
                
            case .authenticating:
                authenticatingView
                
            case .authenticated(let profile):
                authenticatedView(profile: profile)
                
            case .authenticatedYggdrasil(let profile):
                authenticatedYggdrasilView(profile: profile)
                
            case .error(let message):
                errorView(message: message)
            }
        }
        .padding()
    }
    
    // MARK: - 未认证状态
    private var notAuthenticatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60))
                .symbolRenderingMode(.multicolor)
                .symbolVariant(.none)
                .foregroundColor(.secondary)
            Text("minecraft.auth.title".localized())
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("minecraft.auth.subtitle".localized())
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - 请求代码状态
    private var requestingCodeView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.small)
                
            
            Text("minecraft.auth.requesting_code".localized())
                .font(.headline)
            
            Text("minecraft.auth.requesting_code.subtitle".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - 等待用户验证状态
    private func waitingForUserView(userCode: String, verificationUri: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.clock.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("minecraft.auth.waiting_verification".localized())
                .font(.headline)
            
            VStack(spacing: 12) {
                
                
                Text(userCode)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .textSelection(.enabled)
                    .onAppear {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(userCode, forType: .string)
                    }
            }
            
            VStack(spacing: 8) {
                
                
                VStack(alignment: .leading, spacing: 4) {

                    Text("minecraft.auth.step1".localized())
                    Text("minecraft.auth.step2".localized())
                    Text("minecraft.auth.step3".localized())
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
//            Text(String(format: "minecraft.auth.verification_url".localized(), verificationUri))
//                .font(.caption)
//                .foregroundColor(.secondary)
//                .textSelection(.enabled)
        }
    }
    
    // MARK: - 认证中状态
    private var authenticatingView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.small)
            
            Text("minecraft.auth.authenticating".localized())
                .font(.headline)
            
            Text("minecraft.auth.authenticating.subtitle".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - 认证成功状态
    private func authenticatedView(profile: MinecraftProfileResponse) -> some View {
        VStack(spacing: 20) {
            // 用户头像
            if let skinUrl = profile.skins.first?.url {
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
                Text("minecraft.auth.success".localized())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Text(profile.name)
                    .font(.headline)
                
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
    
    private func authenticatedYggdrasilView(profile: YggdrasilProfileResponse) -> some View {
        VStack(spacing: 20) {
            Circle()
                .fill(Color.green.opacity(0.3))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.green)
                )
            VStack(spacing: 8) {
                Text("yggdrasil.auth.success")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Text(profile.username)
                    .font(.headline)
                Text(String(format: "yggdrasil.auth.uuid", profile.id))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                if let selected = profile.selectedProfile {
                    Text(String(format: "yggdrasil.auth.selected_profile", selected.name))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Text("yggdrasil.auth.confirm_login")
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
            
            Text("minecraft.auth.failed".localized())
                .font(.headline)
                .foregroundColor(.red)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("minecraft.auth.retry_message".localized())
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    MinecraftAuthView()
}
