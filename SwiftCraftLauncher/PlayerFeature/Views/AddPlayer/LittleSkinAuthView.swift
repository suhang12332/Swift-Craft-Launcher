import SwiftUI

struct LittleSkinAuthView: View {
    @StateObject private var authService = LittleSkinAuthService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch authService.authState {
            case .idle:
                credentialForm
                helperText("使用 LittleSkin 邮箱和密码登录，将导入所选角色到玩家列表。")
            case .authenticating:
                VStack(spacing: 12) {
                    ProgressView().controlSize(.small)
                    helperText("正在连接 LittleSkin 并获取角色列表")
                }
            case .selectingProfiles(let profiles):
                credentialForm
                VStack(alignment: .leading, spacing: 8) {
                    Text("选择要导入的角色")
                        .font(.headline)
                    Picker("LittleSkin 角色", selection: $authService.selectedProfileId) {
                        ForEach(profiles) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    helperText("一个 LittleSkin 角色会保存为一个本地玩家。若需导入其他角色，请重新登录一次。")
                }
            case .authenticated(let payload):
                VStack(spacing: 16) {
                    MinecraftSkinUtils(type: .url, src: payload.avatarURL, size: 80)
                    VStack(spacing: 6) {
                        Text("LittleSkin 登录成功")
                            .font(.headline)
                            .foregroundStyle(.green)
                        Text(payload.playerName)
                            .font(.title3.bold())
                        Text(payload.playerId)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    helperText("确认后会将该角色添加到玩家列表。")
                }
                .frame(maxWidth: .infinity)
            case .error(let message):
                credentialForm
                VStack(alignment: .leading, spacing: 8) {
                    Text("LittleSkin 登录失败")
                        .font(.headline)
                        .foregroundStyle(.red)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
    }

    private var credentialForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("邮箱")
                    .font(.headline)
                TextField("LittleSkin 邮箱", text: $authService.email)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("密码")
                    .font(.headline)
                SecureField("LittleSkin 密码", text: $authService.password)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func helperText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    LittleSkinAuthView()
}
