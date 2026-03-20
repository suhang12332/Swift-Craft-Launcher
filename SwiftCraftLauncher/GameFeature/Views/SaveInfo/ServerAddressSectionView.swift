import SwiftUI
import AppKit

    // MARK: - 服务器地址区域视图
struct ServerAddressSectionView: View {
    // MARK: - Properties
    let servers: [ServerAddress]
    let isLoading: Bool
    let gameName: String
    let onRefresh: (() -> Void)?

    @StateObject private var viewModel = ServerAddressSectionViewModel()
    @State private var showOverflowPopover = false
    @State private var selectedServer: ServerAddress?
    @State private var showAddServer = false

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
            viewModel.checkAllServers(for: servers)
        }
        .onChange(of: servers) { _, _ in
            viewModel.checkAllServers(for: servers)
        }
    }

    // MARK: - Header Views
    private var headerView: some View {
        let (_, overflowItems) = viewModel.computeVisibleAndOverflowItems(from: servers)
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
        let (_, overflowItems) = viewModel.computeVisibleAndOverflowItems(from: servers)
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
                            connectionStatus: viewModel.serverStatuses[server.id] ?? .unknown
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
        let (visibleItems, _) = viewModel.computeVisibleAndOverflowItems(from: servers)

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
                            connectionStatus: viewModel.serverStatuses[server.id] ?? .unknown
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
}
