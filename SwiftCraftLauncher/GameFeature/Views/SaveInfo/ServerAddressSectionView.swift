import SwiftUI
import AppKit

// MARK: - Constants
private enum ServerAddressSectionConstants {
    static let maxHeight: CGFloat = 235
    static let verticalPadding: CGFloat = 4
    static let headerBottomPadding: CGFloat = 4
    static let placeholderCount: Int = 5
    static let popoverWidth: CGFloat = 320
    static let popoverMaxHeight: CGFloat = 320
    static let chipPadding: CGFloat = 16
    static let estimatedCharWidth: CGFloat = 10
    static let maxItems: Int = 4  // 最多显示4个
    static let maxWidth: CGFloat = 320
}

// MARK: - 服务器地址区域视图
struct ServerAddressSectionView: View {
    // MARK: - Properties
    let servers: [ServerAddress]
    let isLoading: Bool
    let gameName: String
    let onRefresh: (() -> Void)?

    @State private var showOverflowPopover = false
    @State private var selectedServer: ServerAddress?
    @State private var showAddServer = false
    @State private var serverStatuses: [String: ServerConnectionStatus] = [:]

    init(servers: [ServerAddress], isLoading: Bool, gameName: String, onRefresh: (() -> Void)? = nil) {
        self.servers = servers
        self.isLoading = isLoading
        self.gameName = gameName
        self.onRefresh = onRefresh
    }

    // MARK: - Body
    var body: some View {
        VStack {
            headerView
            if isLoading {
                loadingPlaceholder
            } else {
                contentWithOverflow
            }
        }
        .sheet(item: $selectedServer) { server in
            ServerAddressEditView(server: server, gameName: gameName, onRefresh: onRefresh)
        }
        .sheet(isPresented: $showAddServer) {
            ServerAddressEditView(gameName: gameName, onRefresh: onRefresh)
        }
        .onAppear {
            checkAllServers()
        }
        .onChange(of: servers) { _, _ in
            checkAllServers()
        }
    }

    // MARK: - Header Views
    private var headerView: some View {
        let (_, overflowItems) = computeVisibleAndOverflowItems()
        return HStack {
            headerTitle
            Spacer()
            HStack(spacing: 8) {
                addServerButton
                if !overflowItems.isEmpty {
                    overflowButton
                }
            }
        }
        .padding(.bottom, ServerAddressSectionConstants.headerBottomPadding)
    }

    private var addServerButton: some View {
        Button {
            showAddServer = true
        } label: {
            Image(systemName: "plus")
        }
        .buttonStyle(.plain)
    }

    private var headerTitle: some View {
        Text("saveinfo.servers".localized())
            .font(.headline)
    }

    private var overflowButton: some View {
        let (_, overflowItems) = computeVisibleAndOverflowItems()
        return Button {
            showOverflowPopover = true
        } label: {
            Text("+\(overflowItems.count)")
                .font(.caption)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showOverflowPopover, arrowEdge: .leading) {
            overflowPopoverContent
        }
    }

    private var overflowPopoverContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                FlowLayout {
                    // 显示所有服务器
                    ForEach(servers) { server in
                        ServerAddressChip(
                            title: server.name,
                            address: server.address,
                            port: server.port,
                            isLoading: false,
                            connectionStatus: serverStatuses[server.id] ?? .unknown
                        ) {
                            selectedServer = server
                        }
                    }
                }
                .padding()
            }
            .frame(maxHeight: ServerAddressSectionConstants.popoverMaxHeight)
        }
        .frame(width: ServerAddressSectionConstants.popoverWidth)
    }

    // MARK: - Content Views
    private var loadingPlaceholder: some View {
        ScrollView {
            FlowLayout {
                ForEach(
                    0..<ServerAddressSectionConstants.placeholderCount,
                    id: \.self
                ) { _ in
                    ServerAddressChip(
                        title: "common.loading".localized(),
                        address: "",
                        port: nil,
                        isLoading: true,
                        connectionStatus: .unknown
                    )
                    .redacted(reason: .placeholder)
                }
            }
        }
        .frame(maxHeight: ServerAddressSectionConstants.maxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, ServerAddressSectionConstants.verticalPadding)
    }

    private var contentWithOverflow: some View {
        let (visibleItems, _) = computeVisibleAndOverflowItems()

        return Group {
            if servers.isEmpty {
                Text("saveinfo.server.empty".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, ServerAddressSectionConstants.verticalPadding)
                    .padding(.bottom, ServerAddressSectionConstants.verticalPadding)
            } else {
                FlowLayout {
                    ForEach(visibleItems) { server in
                        ServerAddressChip(
                            title: server.name,
                            address: server.address,
                            port: server.port,
                            isLoading: false,
                            connectionStatus: serverStatuses[server.id] ?? .unknown
                        ) {
                            selectedServer = server
                        }
                    }
                }
                .frame(maxHeight: ServerAddressSectionConstants.maxHeight)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, ServerAddressSectionConstants.verticalPadding)
                .padding(.bottom, ServerAddressSectionConstants.verticalPadding)
            }
        }
    }

    // MARK: - Helper Methods
    private func computeVisibleAndOverflowItems() -> (
        [ServerAddress], [ServerAddress]
    ) {
        // 最多显示4个
        let visibleItems = Array(servers.prefix(ServerAddressSectionConstants.maxItems))
        let overflowItems = Array(servers.dropFirst(ServerAddressSectionConstants.maxItems))

        return (visibleItems, overflowItems)
    }

    /// 并发检测所有服务器的连接状态
    private func checkAllServers() {
        guard !servers.isEmpty else { return }

        // 初始化所有服务器状态为检测中
        var initialStatuses: [String: ServerConnectionStatus] = [:]
        for server in servers {
            initialStatuses[server.id] = .checking
        }
        serverStatuses = initialStatuses

        // 并发检测所有服务器
        Task {
            await withTaskGroup(of: (String, ServerConnectionStatus).self) { group in
                for server in servers {
                    group.addTask {
                        let status = await NetworkUtils.checkServerConnectionStatus(
                            address: server.address,
                            port: server.port,
                            timeout: 5.0
                        )
                        return (server.id, status)
                    }
                }

                for await (serverId, status) in group {
                    await MainActor.run {
                        serverStatuses[serverId] = status
                    }
                }
            }
        }
    }
}

// MARK: - Server Address Chip
struct ServerAddressChip: View {
    let title: String
    let address: String
    let port: Int?
    let isLoading: Bool
    let connectionStatus: ServerConnectionStatus
    let action: (() -> Void)?

    init(
        title: String,
        address: String,
        port: Int? = nil,
        isLoading: Bool,
        connectionStatus: ServerConnectionStatus = .unknown,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.address = address
        self.port = port
        self.isLoading = isLoading
        self.connectionStatus = connectionStatus
        self.action = action
    }

    var body: some View {
        Button(action: action ?? {}) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "server.rack")
                        .font(.caption)
                        .foregroundColor(iconColor)
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .frame(maxWidth: 150)
                }
                if !address.isEmpty {
                    if let port = port, port > 0 {
                        Text("\(address):\(String(port))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: 150)
                    } else {
                        Text(address)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: 150)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.clear)
            )
            .foregroundStyle(.primary)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    /// 根据连接状态返回图标颜色
    private var iconColor: Color {
        switch connectionStatus {
        case .success:
            return .green
        case .timeout:
            return .yellow
        case .failed:
            return .red
        case .checking:
            return .blue.opacity(0.5)
        case .unknown:
            return .secondary
        }
    }
}

// MARK: - Server Address Row
struct ServerAddressRow: View {
    let server: ServerAddress

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(server.name)
                    .font(.headline)

                Text(server.fullAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(server.fullAddress, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

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
        if let server = server {
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
                deleteServer()
            }
            Button("common.cancel".localized(), role: .cancel) { }
        } message: {
            Text(String(format: "saveinfo.server.delete_confirmation".localized(), serverName))
        }
    }

    private var headerView: some View {
        Text(isNewServer ? "saveinfo.server.add".localized() : "saveinfo.server.edit".localized())
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                    saveServer()
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
