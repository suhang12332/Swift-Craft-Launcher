//
//  PeerListView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/27.
//

import SwiftUI
import Foundation
import Combine

/// 对等节点列表视图
struct PeerListView: View {
    @State private var peers: [EasyTierPeer] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cancellable: AnyCancellable?

    /// 当前是否有已连接的房间
    private var hasConnectedRoom: Bool {
        EasyTierManager.shared.hasConnectedRoom
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("easytier.peer.list.title".localized())
                    .font(.headline)

                Spacer()

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                Button(action: {
                    Task {
                        await refreshPeers()
                    }
                }, label: {
                    Image(systemName: "arrow.clockwise")
                })
                .buttonStyle(.bordered)
                .disabled(isLoading)
                .help("common.refresh".localized())
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            // 内容区域
            if let errorMessage = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .foregroundColor(.secondary)
                    Button("common.retry".localized()) {
                        Task {
                            await refreshPeers()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if peers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("easytier.peer.list.empty".localized())
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // 表格视图
                Table(peers) {
                    TableColumn("easytier.peer.list.column.ipv4".localized()) { peer in
                        Text(peer.ipv4)
                            .font(.caption)
                    }
                    .width(min: 150, ideal: 150)

                    TableColumn("easytier.peer.list.column.hostname".localized()) { peer in
                        HStack(spacing: 4) {
                            Text(peer.hostname)
                                .font(.caption)
                            if peer.cost == "Local" {
                                Text("easytier.peer.list.local".localized())
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .width(min: 200, ideal: 250)

                    TableColumn("easytier.peer.list.column.type".localized()) { peer in
                        HStack(spacing: 4) {
                            Text(peer.cost)
                                .font(.caption)
                            if peer.cost == "Local" {
                                Image(systemName: "person.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .foregroundColor(peer.cost == "Local" ? .blue : .primary)
                    }
                    .width(min: 80, ideal: 100)

                    TableColumn("easytier.peer.list.column.latency".localized()) { peer in
                        if let latency = peer.latency {
                            Text("\(String(format: "%.1f", latency)) ms")
                                .font(.caption)
                                .foregroundColor(latency < 50 ? .green : (latency < 100 ? .orange : .red))
                        } else {
                            Text("-")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .width(min: 80, ideal: 100)

                    TableColumn("easytier.peer.list.column.packetLoss".localized()) { peer in
                        if let loss = peer.packetLoss {
                            Text("\(String(format: "%.1f", loss))%")
                                .font(.caption)
                                .foregroundColor(loss < 1 ? .green : (loss < 5 ? .orange : .red))
                        } else {
                            Text("-")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .width(min: 80, ideal: 100)

                    TableColumn("easytier.peer.list.column.receive".localized()) { peer in
                        Text(peer.rx)
                            .font(.caption)
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 100, ideal: 120)

                    TableColumn("easytier.peer.list.column.send".localized()) { peer in
                        Text(peer.tx)
                            .font(.caption)
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 100, ideal: 120)

                    TableColumn("easytier.peer.list.column.tunnel".localized()) { peer in
                        Text(peer.tunnel.isEmpty ? "-" : peer.tunnel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .width(min: 60, ideal: 80)

                    TableColumn("easytier.peer.list.column.natType".localized()) { peer in
                        Text(peer.nat)
                            .font(.caption)
                            .foregroundColor(peer.nat.contains("Restricted") ? .orange : .primary)
                    }
                    .width(min: 120, ideal: 150)

                    TableColumn("easytier.peer.list.column.version".localized()) { peer in
                        Text(peer.version)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .width(min: 120, ideal: 150)
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 400)
        .onAppear {
            Task {
                await refreshPeers()
            }
            // 仅在有已连接房间时启动定时刷新（每5秒刷新一次）
            if hasConnectedRoom {
                startAutoRefresh()
            }
        }
        .windowReferenceTracking {
            clearAllData()
        }
    }

    private func refreshPeers() async {
        // 如果房间已关闭或已离开，则停止刷新并清空列表
        guard hasConnectedRoom else {
            await MainActor.run {
                peers = []
                stopAutoRefresh()
            }
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let allPeers = try await EasyTierManager.shared.queryPeers()
            // 只显示有 ipv4 地址的节点
            peers = allPeers.filter { !$0.ipv4.isEmpty }
        } catch {
            errorMessage = error.localizedDescription
            Logger.shared.error("查询对等节点失败: \(error.localizedDescription)")
        }

        isLoading = false
    }

    private func startAutoRefresh() {
        stopAutoRefresh()
        // 使用 Combine 的 Timer 在主线程上执行
        cancellable = Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                Task {
                    await refreshPeers()
                }
            }
    }

    private func stopAutoRefresh() {
        cancellable?.cancel()
        cancellable = nil
    }

    /// 清理所有数据
    private func clearAllData() {
        stopAutoRefresh()
        peers = []
        isLoading = false
        errorMessage = nil
    }
}
