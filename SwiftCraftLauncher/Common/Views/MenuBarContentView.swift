//
//  MenuBarContentView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/5/30.
//

import SwiftUI

/// 菜单栏内容视图（用于响应状态变化）
struct EasyTierContentView: View {
    @ObservedObject private var easyTierManager = EasyTierManager.shared

    var body: some View {
        // 创建房间菜单
        if easyTierManager.hasConnectedRoom && easyTierManager.connectionType == .created {
            Menu("menubar.room.create".localized()) {
                // 显示对等节点简要信息
                if easyTierManager.peers.isEmpty {
                    Text("menubar.room.no_members".localized())
                } else {
                    ForEach(easyTierManager.peers) { peer in
                        Text("\(peer.hostname) | \(peer.ipv4) | \(peer.cost) | \(peer.latency.map { String(format: "%.1f", $0) + " ms" } ?? "-")")
                            .font(.system(.body, design: .monospaced))
                    }
                }

                Divider()

                Button("menubar.room.view_details".localized()) {
                    EasyTierManager.shared.openPeerListWindow()
                }

                Divider()

                Button("menubar.room.close".localized()) {
                    Task {
                        await EasyTierManager.shared.closeRoom()
                    }
                }
            }
        } else {
            Button("menubar.room.create".localized()) {
                EasyTierManager.shared.openCreateRoomWindow()
            }
            .disabled(!easyTierManager.canCreateRoom)
        }

        // 加入房间菜单
        if easyTierManager.hasConnectedRoom && easyTierManager.connectionType == .joined {
            Menu("menubar.room.join".localized()) {
                // 显示对等节点简要信息
                if easyTierManager.peers.isEmpty {
                    Text("menubar.room.no_members".localized())
                } else {
                    ForEach(easyTierManager.peers) { peer in
                        Text("\(peer.hostname) | \(peer.ipv4) | \(peer.cost) | \(peer.latency.map { String(format: "%.1f", $0) + " ms" } ?? "-")")
                    }
                }

                Divider()

                Button("menubar.room.view_details".localized()) {
                    EasyTierManager.shared.openPeerListWindow()
                }

                Divider()

                Button("menubar.room.leave".localized()) {
                    Task {
                        await EasyTierManager.shared.leaveRoom()
                    }
                }
            }
        } else {
            Button("menubar.room.join".localized()) {
                EasyTierManager.shared.openJoinRoomWindow()
            }
            .disabled(!easyTierManager.canJoinRoom)
        }

        Divider()

        // 直接关闭 EasyTier 菜单
        Button("menubar.easytier.close".localized()) {
            Task {
                await EasyTierManager.shared.forceCloseEasyTier()
            }
        }
    }
}
