//
//  CustomYggdrasilServerSheet.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Management sheet for custom Yggdrasil skin sites: lists added servers (removable)
/// and provides a form to add new ones.
///
/// Adding a server: enter the authlib-injector API root, verify it (fetches metadata),
/// review the server name, then save. Servers still referenced by players cannot be
/// removed. The list comes from the observable ``CustomYggdrasilServerStore``, so
/// changes propagate to every view immediately.
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
                    .onChange(of: apiRootText) { _, newValue in
                        // Editing the address invalidates the previous verification.
                        if CustomYggdrasilServerStore.normalizeAPIRoot(newValue) != verifiedAPIRoot {
                            verifiedAPIRoot = nil
                            serverName = ""
                            nonEmailLogin = false
                        }
                    }

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
        guard let verifiedAPIRoot else { return }
        do {
            _ = try container.system.customYggdrasilServerStore.add(
                name: serverName,
                apiRoot: verifiedAPIRoot,
                nonEmailLogin: nonEmailLogin,
            )
            apiRootText = ""
            serverName = ""
            nonEmailLogin = false
            self.verifiedAPIRoot = nil
        } catch {
            errorMessage = GlobalError.from(error).localizedDescription
        }
    }

    private func removeServer(_ server: CustomYggdrasilServer) {
        errorMessage = nil
        do {
            try container.system.customYggdrasilServerStore.remove(
                id: server.id,
                referencedBaseURLs: YggdrasilServerRegistry.referencedServerBaseURLs(),
            )
            // If the removed server is the one selected in the add-account flow, sign out
            // of it so a profile authenticated against it can no longer be added.
            let authService = container.system.yggdrasilAuthService
            if authService.currentServer?.baseURL.absoluteString == CustomYggdrasilServerStore.configBaseURL(for: server) {
                authService.logout()
            }
        } catch {
            errorMessage = GlobalError.from(error).localizedDescription
        }
    }
}
