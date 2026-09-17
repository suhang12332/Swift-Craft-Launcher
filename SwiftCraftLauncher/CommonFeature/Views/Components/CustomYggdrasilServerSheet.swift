//
//  CustomYggdrasilServerSheet.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// 自定义 Yggdrasil 皮肤站管理面板:展示已添加列表(可删除)并提供添加表单。
///
/// 添加流程:输入 authlib-injector API 根地址 → 验证(拉取元数据)→
/// 显示站点名称 → 保存。被玩家档案引用的服务器会被阻止删除。
/// 列表数据来自可观察的 `CustomYggdrasilServerStore`,增删即时同步所有视图。
struct CustomYggdrasilServerSheet: View {
    @Environment(DIContainer.self)
    private var container
    @Environment(\.dismiss)
    private var dismiss

    @State private var apiRootText = ""
    @State private var serverName = ""
    @State private var nonEmailLogin = false
    @State private var isVerifying = false
    @State private var verifiedAPIRoot: String?
    @State private var errorMessage: String?

    private var servers: [CustomYggdrasilServer] {
        container.system.customYggdrasilServerStore.servers
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("yggdrasil.custom.title".localized())
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if !servers.isEmpty {
                serverListSection
            }

            addFormSection

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    // MARK: - 已有服务器列表

    private var serverListSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("yggdrasil.custom.existing".localized())
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(servers) { server in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.serverName)
                            .font(.callout)
                        Text(server.apiRoot)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button {
                        removeServer(server)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("yggdrasil.custom.delete".localized())
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - 添加表单

    private var addFormSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("yggdrasil.custom.add".localized())
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                TextField("yggdrasil.custom.url".localized(), text: $apiRootText)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.URL)
                    .disableAutocorrection(true)

                Button {
                    verifyAPIRoot()
                } label: {
                    if isVerifying {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("yggdrasil.custom.verify".localized())
                    }
                }
                .disabled(apiRootText.trimmingCharacters(in: .whitespaces).isEmpty || isVerifying)
            }

            if verifiedAPIRoot != nil {
                TextField("yggdrasil.custom.server_name".localized(), text: $serverName)
                    .textFieldStyle(.roundedBorder)

                if nonEmailLogin {
                    Label("yggdrasil.custom.non_email_login_hint".localized(), systemImage: "person.text.rectangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    saveServer()
                } label: {
                    Text("yggdrasil.custom.save".localized())
                }
                .buttonStyle(.borderedProminent)
                .disabled(serverName.isEmpty)
            }
        }
    }

    // MARK: - 动作

    private func verifyAPIRoot() {
        errorMessage = nil
        isVerifying = true
        let input = apiRootText
        Task {
            do {
                let metadata = try await CustomYggdrasilServerStore.fetchMetadata(apiRoot: input)
                await MainActor.run {
                    serverName = metadata.serverName
                    nonEmailLogin = metadata.nonEmailLogin
                    verifiedAPIRoot = CustomYggdrasilServerStore.normalizeAPIRoot(input)
                    isVerifying = false
                }
            } catch {
                await MainActor.run {
                    verifiedAPIRoot = nil
                    errorMessage = GlobalError.from(error).localizedDescription
                    isVerifying = false
                }
            }
        }
    }

    private func saveServer() {
        errorMessage = nil
        do {
            _ = try container.system.customYggdrasilServerStore.add(
                name: serverName,
                apiRoot: verifiedAPIRoot ?? apiRootText,
                nonEmailLogin: nonEmailLogin,
            )
            apiRootText = ""
            serverName = ""
            nonEmailLogin = false
            verifiedAPIRoot = nil
        } catch {
            errorMessage = GlobalError.from(error).localizedDescription
        }
    }

    private func removeServer(_ server: CustomYggdrasilServer) {
        errorMessage = nil
        do {
            try container.system.customYggdrasilServerStore.remove(
                id: server.id,
                referencedBaseURLs: YggdrasilServerRegistry.referencedYggdrasilBaseURLs,
            )
        } catch {
            errorMessage = GlobalError.from(error).localizedDescription
        }
    }
}
