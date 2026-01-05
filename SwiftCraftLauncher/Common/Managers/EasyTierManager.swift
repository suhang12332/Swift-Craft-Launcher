import Foundation
import SwiftUI
import AppKit
import Combine

/// 房间连接类型
enum RoomConnectionType {
    case disconnected  // 未连接
    case created  // 创建的房间
    case joined   // 加入的房间
}

/// EasyTier 联机功能管理器
@MainActor
class EasyTierManager: ObservableObject {
    static let shared = EasyTierManager()

    private let easyTierService = EasyTierService.shared

    /// 当前房间连接类型
    @Published private(set) var connectionType: RoomConnectionType = .disconnected

    /// 对等节点列表
    @Published private(set) var peers: [EasyTierPeer] = []

    /// 定时刷新任务（使用 nonisolated 包装以支持在 deinit 中取消）
    nonisolated(unsafe) private var refreshTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // 监听连接类型变化，自动开始/停止刷新
        $connectionType
            .sink { [weak self] connectionType in
                Task { @MainActor [weak self] in
                    if connectionType != .disconnected {
                        // 延迟一点时间，确保网络已连接
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                        if self?.hasConnectedRoom == true {
                            await self?.startPeerRefresh()
                        }
                    } else {
                        self?.stopPeerRefresh()
                        self?.peers = []
                    }
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        refreshTask?.cancel()
    }

    /// 打开创建房间窗口
    func openCreateRoomWindow() {
        let generalSettingsManager = GeneralSettingsManager.shared
        TemporaryWindowManager.shared.showWindow(
            content: CreateRoomWindowView()
                .environmentObject(generalSettingsManager)
                .preferredColorScheme(generalSettingsManager.currentColorScheme),
            config: .easyTierCreateRoom(title: "menubar.room.create".localized())
        )
    }

    /// 打开加入房间窗口
    func openJoinRoomWindow() {
        let generalSettingsManager = GeneralSettingsManager.shared
        TemporaryWindowManager.shared.showWindow(
            content: JoinRoomWindowView()
                .environmentObject(generalSettingsManager)
                .preferredColorScheme(generalSettingsManager.currentColorScheme),
            config: .easyTierJoinRoom(title: "menubar.room.join".localized())
        )
    }

    /// 打开对等节点列表窗口
    func openPeerListWindow() {
        let generalSettingsManager = GeneralSettingsManager.shared
        TemporaryWindowManager.shared.showWindow(
            content: PeerListView()
                .environmentObject(generalSettingsManager)
                .preferredColorScheme(generalSettingsManager.currentColorScheme),
            config: .peerList(title: "menubar.room.member_list".localized())
        )
    }

    /// 检查是否有已连接的房间
    var hasConnectedRoom: Bool {
        guard easyTierService.currentRoom != nil else { return false }
        switch easyTierService.getNetworkStatus() ?? .disconnected {
        case .connected:
            return true
        default:
            return false
        }
    }

    /// 关闭房间（创建的房间）
    func closeRoom() async {
        await easyTierService.stopNetwork()
        connectionType = .disconnected
        Logger.shared.info("房间已关闭")
    }

    /// 离开房间（加入的房间）
    func leaveRoom() async {
        await easyTierService.stopNetwork()
        connectionType = .disconnected
        Logger.shared.info("已离开房间")
    }

    /// 设置房间连接类型（创建房间）
    func setRoomCreated() {
        connectionType = .created
    }

    /// 设置房间连接类型（加入房间）
    func setRoomJoined() {
        connectionType = .joined
    }

    /// 检查是否可以创建房间
    var canCreateRoom: Bool {
        connectionType == .disconnected
    }

    /// 检查是否可以加入房间
    var canJoinRoom: Bool {
        connectionType == .disconnected
    }

    /// 查询对等节点列表
    func queryPeers() async throws -> [EasyTierPeer] {
        return try await easyTierService.queryPeers()
    }

    /// 开始定时刷新对等节点列表
    private func startPeerRefresh() async {
        stopPeerRefresh()

        // 立即刷新一次
        await refreshPeers()

        // 每5秒刷新一次
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒
                if !Task.isCancelled {
                    await refreshPeers()
                }
            }
        }
    }

    /// 停止定时刷新
    private func stopPeerRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    /// 刷新对等节点列表
    private func refreshPeers() async {
        guard hasConnectedRoom else {
            peers = []
            return
        }

        do {
            let allPeers = try await queryPeers()
            // 只显示有 ipv4 地址的节点
            peers = allPeers.filter { !$0.ipv4.isEmpty }
        } catch {
            Logger.shared.error("刷新对等节点列表失败: \(error.localizedDescription)")
            // 刷新失败时不更新列表，保留旧数据
        }
    }

    /// 手动刷新对等节点列表（供外部调用）
    func refreshPeersManually() async {
        await refreshPeers()
    }
}
