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

            case .processingAuthCode(let step):
                processingAuthCodeView(step: step)

            case .authenticated(let profile):
                authenticatedView(profile: profile)

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
    private func processingAuthCodeView(step: String) -> some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.small)

            Text(step)
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
