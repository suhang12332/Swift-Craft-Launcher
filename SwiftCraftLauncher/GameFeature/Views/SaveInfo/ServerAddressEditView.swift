import SwiftUI
import AppKit

// MARK: - Server Address Edit View
struct ServerAddressEditView: View {
    let server: ServerAddress?
    let gameName: String
    let serverInfo: MinecraftServerInfo?
    let onRefresh: (() -> Void)?
    @Environment(\.dismiss)
    private var dismiss

    @State private var serverName: String
    @State private var serverAddress: String
    @State private var serverPort: String
    @State private var isHidden: Bool
    @State private var acceptTextures: Bool
    @StateObject private var actionViewModel = ServerAddressEditActionViewModel()
    @State private var showDeleteConfirmation: Bool = false

    var isNewServer: Bool {
        server == nil
    }

    init(server: ServerAddress? = nil, gameName: String, serverInfo: MinecraftServerInfo? = nil, onRefresh: (() -> Void)? = nil) {
        self.server = server
        self.gameName = gameName
        self.serverInfo = serverInfo
        self.onRefresh = onRefresh
        if let server {
            _serverName = State(initialValue: server.name)
            _serverAddress = State(initialValue: server.address)
            // 如果端口为0，表示未设置，显示为空
            _serverPort = State(initialValue: server.port > 0 ? String(server.port) : "")
            _isHidden = State(initialValue: server.hidden)
            _acceptTextures = State(initialValue: server.acceptTextures)
        } else {
            _serverName = State(initialValue: "")
            _serverAddress = State(initialValue: "")
            _serverPort = State(initialValue: "")
            _isHidden = State(initialValue: false)
            _acceptTextures = State(initialValue: false)
        }
    }

    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: { bodyView },
            footer: { footerView }
        )
        .alert("common.error".localized(), isPresented: $actionViewModel.showError) {
            Button("common.ok".localized(), role: .cancel) { }
        } message: {
            Text(actionViewModel.errorMessage)
        }
        .confirmationDialog("saveinfo.server.delete_title".localized(), isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("common.delete".localized(), role: .destructive) {
                confirmDeleteServer()
            }
            Button("common.cancel".localized(), role: .cancel) { }
        } message: {
            Text(String(format: "saveinfo.server.delete_confirmation".localized(), serverName))
        }
    }

    private var headerView: some View {
        HStack {
            Text(isNewServer ? "saveinfo.server.add".localized() : "saveinfo.server.edit".localized())
                .font(.headline)
            Spacer()
            if let shareTextForServer, !shareTextForServer.isEmpty {
                ShareLink(item: shareTextForServer) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.borderless)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var shareTextForServer: String? {
        let address = serverAddress.trimmingCharacters(in: .whitespaces)
        let port = serverPort.trimmingCharacters(in: .whitespaces)

        if !address.isEmpty {
            if !port.isEmpty {
                return "\(address):\(port)"
            } else {
                return address
            }
        }

        if let existing = server {
            return existing.fullAddress
        }

        return nil
    }

    private var bodyView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 服务器信息卡片
            if let serverInfo = serverInfo {
                serverInfoCard(serverInfo)
            }

            Text("saveinfo.server.name".localized())
            TextField("saveinfo.server.name".localized(), text: $serverName)
                .textFieldStyle(.roundedBorder)

            HStack {
                VStack(alignment: .leading) {
                    Text("saveinfo.server.address".localized())
                    TextField("saveinfo.server.address".localized(), text: $serverAddress)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: serverAddress) { _, newValue in
                            // 如果地址包含端口，自动分离到端口字段
                            if let colonIndex = newValue.lastIndex(of: ":") {
                                let afterColon = String(newValue[newValue.index(after: colonIndex)...])
                                if let port = Int(afterColon), port > 0 && port <= 65535 {
                                    // 地址包含有效端口
                                    let addressOnly = String(newValue[..<colonIndex])
                                    if serverAddress != addressOnly {
                                        serverAddress = addressOnly
                                    }
                                    if serverPort != afterColon {
                                        serverPort = afterColon
                                    }
                                }
                            }
                        }
                }
                VStack(alignment: .leading) {
                    Text("saveinfo.server.port".localized())
                    TextField("saveinfo.server.port.placeholder".localized(), text: $serverPort)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 100)
                }
            }

            HStack {
                Toggle("saveinfo.server.hidden".localized(), isOn: $isHidden)
                Spacer()
                Toggle("saveinfo.server.accept_textures".localized(), isOn: $acceptTextures)
            }
        }
    }

    private func serverInfoCard(_ info: MinecraftServerInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 服务器图标和版本
            HStack(spacing: 12) {
                // 服务器图标
                if let favicon = info.favicon,
                   let imageData = CommonUtil.imageDataFromBase64(favicon),
                   let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .cornerRadius(4)
                } else {
                    Image(systemName: "server.rack")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                        .frame(width: 48, height: 48)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // 版本信息
                    if let version = info.version {
                        HStack(spacing: 4) {
                            Image(systemName: "cube")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(version.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }

                    // 玩家数量
                    if let players = info.players {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(players.online) / \(players.max)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }

            // 描述
            if !info.description.plainText.isEmpty {
                Divider()
                Text(info.description.plainText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    private var footerView: some View {
        HStack {
            Button("common.cancel".localized()) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .disabled(actionViewModel.isSaving || actionViewModel.isDeleting)
            if !isNewServer {
                Button("common.delete".localized()) {
                    deleteServer()
                }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(actionViewModel.isSaving || actionViewModel.isDeleting)
            }
            Spacer()
            Button("common.save".localized()) {
                saveServer()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(actionViewModel.isSaving || actionViewModel.isDeleting || !isFormValid)
        }
    }

    private var isFormValid: Bool {
        let trimmedName = serverName.trimmingCharacters(in: .whitespaces)
        let trimmedAddress = serverAddress.trimmingCharacters(in: .whitespaces)
        let trimmedPort = serverPort.trimmingCharacters(in: .whitespaces)

        // 名称和地址必填，端口可选
        guard !trimmedName.isEmpty && !trimmedAddress.isEmpty else {
            return false
        }

        // 如果端口不为空，则必须是有效数字
        if !trimmedPort.isEmpty {
            return Int(trimmedPort) != nil
        }

        return true
    }

    /// 获取端口号，如果为空则返回 nil
    private var portValue: Int? {
        let trimmedPort = serverPort.trimmingCharacters(in: .whitespaces)
        if trimmedPort.isEmpty {
            return nil
        }
        return Int(trimmedPort)
    }

    private func saveServer() {
        let port = portValue ?? 0
        let request = ServerAddressEditActionViewModel.SaveRequest(
            existing: server,
            gameName: gameName,
            name: serverName,
            address: serverAddress,
            port: port,
            hidden: isHidden,
            acceptTextures: acceptTextures
        )

        actionViewModel.saveServer(request: request, dismiss: { dismiss() }, onRefresh: onRefresh)
    }

    /// 删除服务器
    private func deleteServer() {
        guard server != nil else {
            return
        }

        // 显示删除确认弹窗
        showDeleteConfirmation = true
    }

    /// 确认删除服务器
    private func confirmDeleteServer() {
        actionViewModel.deleteServer(
            serverToDelete: server,
            gameName: gameName,
            dismiss: { dismiss() },
            onRefresh: onRefresh
        )
    }
}
