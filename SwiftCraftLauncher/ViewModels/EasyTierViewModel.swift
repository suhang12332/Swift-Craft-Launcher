import Foundation
import SwiftUI

/// EasyTier 联机功能 ViewModel
@MainActor
class EasyTierViewModel: ObservableObject {
    // MARK: - Published Properties

    /// 当前房间
    @Published private(set) var currentRoom: EasyTierRoom?

    /// 网络状态
    @Published private(set) var networkStatus: EasyTierNetworkStatus = .disconnected

    /// 是否正在连接
    @Published private(set) var isConnecting: Bool = false

    /// 输入的房间码（用于加入房间）
    @Published var inputRoomCode: String = ""

    /// 错误消息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let easyTierService = EasyTierService.shared

    // MARK: - Public Methods

    /// 创建新房间
    func createRoom() {
        // 清除之前的输入房间码，切换到创建模式
        inputRoomCode = ""
        errorMessage = nil

        let room = easyTierService.createRoom()
        currentRoom = room
        inputRoomCode = room.roomCode
        Logger.shared.info("创建房间: \(room.roomCode)")
    }

    /// 加入房间
    func joinRoom() {
        guard !inputRoomCode.isEmpty else {
            errorMessage = "error.validation.room_code_required".localized()
            return
        }

        guard let room = easyTierService.joinRoom(roomCode: inputRoomCode) else {
            errorMessage = "error.configuration.invalid_room_code".localized()
            return
        }

        currentRoom = room
        errorMessage = nil
        Logger.shared.info("加入房间: \(room.roomCode)")
    }

    /// 清除当前房间（切换到输入模式）
    func clearRoom() {
        currentRoom = nil
        inputRoomCode = ""
        errorMessage = nil
        networkStatus = .disconnected
    }

    /// 启动网络连接
    func startNetwork() async {
        isConnecting = true
        errorMessage = nil
        networkStatus = .connecting

        do {
            // 如果有当前房间，使用房间对象启动
            if let room = currentRoom {
                try await easyTierService.startNetwork(room: room)
            } else if !inputRoomCode.isEmpty {
                // 如果没有房间但有输入的房间码，直接使用房间码启动
                try await easyTierService.startNetwork(roomCode: inputRoomCode)
                // 启动成功后，获取当前房间信息
                currentRoom = easyTierService.currentRoom
            }
            networkStatus = .connected
            currentRoom = easyTierService.currentRoom
            Logger.shared.info("网络连接成功")
        } catch {
            GlobalErrorHandler.shared.handle(error)
        }

        isConnecting = false
    }

    /// 停止网络连接
    func stopNetwork() async {
        isConnecting = true

        await easyTierService.stopNetwork()
        networkStatus = .disconnected
        currentRoom = nil
        errorMessage = nil

        isConnecting = false
        Logger.shared.info("网络连接已停止")
    }

    /// 刷新网络状态
    func refreshStatus() {
        networkStatus = easyTierService.getNetworkStatus() ?? .disconnected
        currentRoom = easyTierService.currentRoom
    }

    /// 复制房间码到剪贴板
    func copyRoomCode() {
        guard let roomCode = currentRoom?.roomCode else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(roomCode, forType: .string)

        Logger.shared.debug("房间码已复制到剪贴板: \(roomCode)")
    }
}
