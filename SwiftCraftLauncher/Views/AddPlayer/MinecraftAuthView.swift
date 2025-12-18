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
//                waitingForBrowserAuthView
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
        .padding()
        .onDisappear {
            // 页面关闭后清除所有数据
            clearAllData()
        }
    }

    // MARK: - 清除数据
    /// 清除页面所有数据
    private func clearAllData() {
        // 重置认证服务状态（如果未完成认证）
        if case .notAuthenticated = authService.authState {
            authService.isLoading = false
        }
        // 注意：如果已经认证成功，不清除状态，因为可能需要使用认证信息
    }

    // MARK: - 未认证状态
    private var notAuthenticatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 46))
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

    // MARK: - 等待浏览器授权状态
    private var waitingForBrowserAuthView: some View {
        VStack(spacing: 16) {
            // 浏览器图标
            Image(systemName: "person.crop.circle.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("minecraft.auth.waiting_browser".localized())
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("minecraft.auth.waiting_browser.subtitle".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 处理授权码状态
    private var processingAuthCodeView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.small)

            Text("minecraft.auth.processing.title".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Text("minecraft.auth.processing.subtitle".localized())
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 认证成功状态
    private func authenticatedView(
        profile: MinecraftProfileResponse
    ) -> some View {
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

                Text(
                    String(
                        format: "minecraft.auth.uuid".localized(),
                        profile.id
                    )
                )
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
