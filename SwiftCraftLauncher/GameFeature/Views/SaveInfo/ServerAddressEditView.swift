import SwiftUI

// MARK: - Server Address Edit View
struct ServerAddressEditView: View {
    let server: ServerAddress?
    let gameName: String
    let onRefresh: (() -> Void)?
    @Environment(\.dismiss)
    private var dismiss

    @State private var serverName: String
    @State private var serverAddress: String
    @State private var serverPort: String
    @State private var isHidden: Bool
    @State private var acceptTextures: Bool
    @State private var isSaving: Bool = false
    @State private var isDeleting: Bool = false
    @State private var showError: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var errorMessage: String = ""

    var isNewServer: Bool {
        server == nil
    }

    init(server: ServerAddress? = nil, gameName: String, onRefresh: (() -> Void)? = nil) {
        self.server = server
        self.gameName = gameName
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
        .alert("common.error".localized(), isPresented: $showError) {
            Button("common.ok".localized(), role: .cancel) { }
        } message: {
            Text(errorMessage)
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
        VStack(alignment: .leading) {
            Text("saveinfo.server.name".localized())
            TextField("saveinfo.server.name".localized(), text: $serverName)
                .textFieldStyle(.roundedBorder)
                .padding(.bottom, 20)

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
            .padding(.bottom, 20)

            HStack {
                Toggle("saveinfo.server.hidden".localized(), isOn: $isHidden)
                Spacer()
                Toggle("saveinfo.server.accept_textures".localized(), isOn: $acceptTextures)
            }
            .padding(.bottom, 20)
        }
    }

    private var footerView: some View {
        HStack {
            Button("common.cancel".localized()) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .disabled(isSaving || isDeleting)
            if !isNewServer {
                Button("common.delete".localized()) {
                    deleteServer()
                }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(isSaving || isDeleting)
            }
            Spacer()
            Button("common.save".localized()) {
                saveServer()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(isSaving || isDeleting || !isFormValid)
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
        let trimmedName = serverName.trimmingCharacters(in: .whitespaces)
        let trimmedAddress = serverAddress.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty && !trimmedAddress.isEmpty else {
            errorMessage = "saveinfo.server.invalid_fields".localized()
            showError = true
            return
        }

        // 端口可选，如果为空则不保存端口（保存为0，表示未设置）
        let port = portValue ?? 0

        isSaving = true

        Task {
            do {
                // 获取当前服务器列表
                var currentServers = try await ServerAddressService.shared.loadServerAddresses(for: gameName)

                if let existingServer = server {
                    // 编辑模式：更新现有服务器
                    let updatedServer = ServerAddress(
                        id: existingServer.id,
                        name: trimmedName,
                        address: trimmedAddress,
                        port: port,
                        hidden: isHidden,
                        icon: existingServer.icon,
                        acceptTextures: acceptTextures
                    )

                    // 找到并更新服务器
                    if let index = currentServers.firstIndex(where: { $0.id == existingServer.id }) {
                        currentServers[index] = updatedServer
                    } else {
                        // 如果找不到，添加新的
                        currentServers.append(updatedServer)
                    }
                } else {
                    // 新增模式：添加新服务器
                    let newServer = ServerAddress(
                        name: trimmedName,
                        address: trimmedAddress,
                        port: port,
                        hidden: isHidden,
                        icon: nil,
                        acceptTextures: acceptTextures
                    )
                    currentServers.append(newServer)
                }

                // 保存服务器列表
                try await ServerAddressService.shared.saveServerAddresses(currentServers, for: gameName)

                await MainActor.run {
                    isSaving = false
                    dismiss()
                    // 刷新服务器列表
                    onRefresh?()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
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
        guard let serverToDelete = server else {
            return
        }

        isDeleting = true

        Task {
            do {
                // 获取当前服务器列表
                var currentServers = try await ServerAddressService.shared.loadServerAddresses(for: gameName)

                // 移除要删除的服务器
                currentServers.removeAll { $0.id == serverToDelete.id }

                // 保存服务器列表
                try await ServerAddressService.shared.saveServerAddresses(currentServers, for: gameName)

                await MainActor.run {
                    isDeleting = false
                    dismiss()
                    // 刷新服务器列表
                    onRefresh?()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

