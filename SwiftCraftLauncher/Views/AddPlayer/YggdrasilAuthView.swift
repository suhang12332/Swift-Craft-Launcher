//
//  YggdrasilAuthView.swift
//  SwiftCraftLauncher
//
//  Created by rayanceking on 2025/8/17.
//

import SwiftUI

struct YggdrasilAuthView: View {
    @StateObject private var authService = YggdrasilAuthService.shared
    var onLoginSuccess: ((YggdrasilProfileResponse) -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            switch authService.authState {
            case .notAuthenticated:
                notAuthenticatedView
            case .requestingCode:
                requestingCodeView
            case .waitingForUser(let userCode, let verificationUri):
                waitingForUserView(userCode: userCode, verificationUri: verificationUri)
            case .authenticating:
                authenticatingView
            case .authenticatedYggdrasil(let profile):
                authenticatedView(profile: profile)
            case .authenticated:
                // 兼容旧的 MinecraftProfileResponse
                authenticatedLegacyView
            case .error(let message):
                errorView(message: message)
            }
        }
        .padding()
    }

    // MARK: - 未认证状态
    private var notAuthenticatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("yggdrasil.auth.title".localized())
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("yggdrasil.auth.subtitle".localized())
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 请求代码状态
    private var requestingCodeView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.small)
            Text("yggdrasil.auth.requesting_code".localized())
                .font(.headline)
            Text("yggdrasil.auth.requesting_code.subtitle".localized())
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
            Text("yggdrasil.auth.waiting_verification".localized())
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
                        #if canImport(AppKit)
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(userCode, forType: .string)
                        #endif
                    }
            }
            VStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("yggdrasil.auth.step1".localized())
                    Text("yggdrasil.auth.step2".localized())
                    Text("yggdrasil.auth.step3".localized())
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 认证中状态
    private var authenticatingView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.small)
            Text("yggdrasil.auth.authenticating".localized())
                .font(.headline)
            Text("yggdrasil.auth.authenticating.subtitle".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 认证成功状态
    private func authenticatedView(profile: YggdrasilProfileResponse) -> some View {
        VStack(spacing: 20) {
            // 用户信息，可以扩展头像显示等
            Circle()
                .fill(Color.green.opacity(0.3))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.green)
                )
            VStack(spacing: 8) {
                Text("yggdrasil.auth.success".localized())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Text(profile.username)
                    .font(.headline)
                Text(String(format: "yggdrasil.auth.uuid".localized(), profile.id))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                if let selected = profile.selectedProfile {
                    Text(String(format: "yggdrasil.auth.selected_profile".localized(), selected.name))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Text("yggdrasil.auth.confirm_login".localized())
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // 兼容旧结构，防止 authState = .authenticated(profile: MinecraftProfileResponse) 情况下崩溃
    private var authenticatedLegacyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text("yggdrasil.auth.success_legacy".localized())
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.green)
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
            Text("yggdrasil.auth.retry_message".localized())
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    YggdrasilAuthView()
}
