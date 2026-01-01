import SwiftUI

/// Yggdrasil 三方登录服务器设置视图
public struct YggdrasilServerSettingsView: View {
    @StateObject private var serverManager = YggdrasilServerManager.shared
    @State private var showingAddSheet = false
    @State private var editingServer: YggdrasilServerConfig?
    @State private var showingDeleteAlert = false
    @State private var serverToDelete: YggdrasilServerConfig?
    @State private var errorMessage = ""
    @State private var showingErrorAlert = false
    
    public init() {}
    
    public var body: some View {
        Form {
            // 添加服务器按钮
            Section {
                Button(action: {
                    editingServer = nil
                    showingAddSheet = true
                }) {
                    Label("yggdrasil.settings.add_server".localized(), systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            
            // 服务器列表
            if serverManager.servers.isEmpty {
                Section {
                    Text("yggdrasil.settings.no_servers".localized())
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            } else {
                Section(header: Text("yggdrasil.settings.servers_list".localized())) {
                    ForEach(serverManager.servers, id: \.baseURL) { server in
                        ServerRowView(
                            server: server,
                            onEdit: {
                                editingServer = server
                                showingAddSheet = true
                            },
                            onDelete: {
                                serverToDelete = server
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ServerEditSheet(
                server: editingServer,
                onSave: { server in
                    if let editingServer = editingServer {
                        // 更新现有服务器
                        if !serverManager.updateServer(oldServer: editingServer, newServer: server) {
                            showError("yggdrasil.settings.error.update_failed".localized())
                        }
                    } else {
                        // 添加新服务器
                        if !serverManager.addServer(server) {
                            showError("yggdrasil.settings.error.add_failed".localized())
                        }
                    }
                    showingAddSheet = false
                },
                onCancel: {
                    showingAddSheet = false
                }
            )
        }
        .alert("yggdrasil.settings.delete_confirm.title".localized(), isPresented: $showingDeleteAlert) {
            Button("common.cancel".localized(), role: .cancel) {
                serverToDelete = nil
            }
            Button("common.delete".localized(), role: .destructive) {
                if let server = serverToDelete {
                    if !serverManager.deleteServer(server) {
                        showError("yggdrasil.settings.error.delete_failed".localized())
                    }
                    serverToDelete = nil
                }
            }
        } message: {
            if let server = serverToDelete {
                Text(String(format: "yggdrasil.settings.delete_confirm.message".localized(), server.baseURL))
            }
        }
        .alert("common.error".localized(), isPresented: $showingErrorAlert) {
            Button("common.ok".localized()) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingErrorAlert = true
    }
}

// MARK: - Server Row View
private struct ServerRowView: View {
    let server: YggdrasilServerConfig
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Text(server.baseURL)
                .font(.headline)
                .lineLimit(1)
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("common.edit".localized())
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
                .help("common.delete".localized())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Server Edit Sheet
private struct ServerEditSheet: View {
    let server: YggdrasilServerConfig?
    let onSave: (YggdrasilServerConfig) -> Void
    let onCancel: () -> Void
    
    @State private var baseURL: String = ""
    @State private var isURLValid: Bool = false
    @State private var showURLError: Bool = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        CommonSheetView(
            header: {
                Text(server == nil ? "yggdrasil.settings.add_server".localized() : "yggdrasil.settings.edit_server".localized())
                    .font(.headline)
            },
            body: {
                VStack(alignment: .leading, spacing: 16) {
                    // 服务器基础URL
                    VStack(alignment: .leading, spacing: 4) {
                        Text("yggdrasil.settings.server_url".localized())
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField(
                            "yggdrasil.settings.server_url.placeholder".localized(),
                            text: $baseURL
                        )
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                        .onChange(of: baseURL) { _, newValue in
                            validateURL(newValue)
                        }
                        if showURLError {
                            Text("yggdrasil.settings.error.invalid_url".localized())
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Text("yggdrasil.settings.server_url.hint".localized())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            },
            footer: {
                HStack {
                    Button("common.cancel".localized(), action: onCancel)
                    Spacer()
                    Button(
                        server == nil ? "common.add".localized() : "common.save".localized(),
                        action: saveServer
                    )
                    .buttonStyle(.borderedProminent)
                    .disabled(!isURLValid)
                    .keyboardShortcut(.defaultAction)
                }
            }
        )
        .onAppear {
            if let server = server {
                baseURL = server.baseURL
            }
            validateURL(baseURL)
        }
    }
    
    private func validateURL(_ urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            isURLValid = false
            showURLError = false
            return
        }
        
        // 尝试创建 URL
        if let url = URL(string: trimmed) {
            // 检查是否是有效的 HTTP/HTTPS URL
            if let scheme = url.scheme, (scheme == "http" || scheme == "https") {
                isURLValid = true
                showURLError = false
            } else {
                isURLValid = false
                showURLError = true
            }
        } else {
            isURLValid = false
            showURLError = true
        }
    }
    
    private func saveServer() {
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL) else {
            return
        }
        
        let config = YggdrasilServerConfig(
            baseURL: url.absoluteString
        )
        
        onSave(config)
    }
}

#Preview {
    YggdrasilServerSettingsView()
}

