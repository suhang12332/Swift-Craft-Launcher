//
//  MinecraftServerPing.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/20.
//

import Foundation
@preconcurrency import Dispatch
@preconcurrency import Network

/// Minecraft 服务器信息
struct MinecraftServerInfo: Codable {
    /// 服务器版本信息
    struct Version: Codable {
        let name: String
        let `protocol`: Int? // 使用反引号因为 protocol 是 Swift 关键字
    }

    /// 玩家信息
    struct Players: Codable {
        let max: Int
        let online: Int
        let sample: [Player]?

        struct Player: Codable {
            let name: String
            let id: String?
        }
    }

    /// 服务器描述（MOTD）
    struct Description: Codable {
        let text: String?
        let extra: [DescriptionElement]?

        /// 描述元素（可以是字符串或 Description 对象）
        enum DescriptionElement: Codable {
            case string(String)
            case object(Description)

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let string = try? container.decode(String.self) {
                    self = .string(string)
                } else {
                    let object = try container.decode(Description.self)
                    self = .object(object)
                }
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .string(let string):
                    try container.encode(string)
                case .object(let description):
                    try container.encode(description)
                }
            }

            var plainText: String {
                switch self {
                case .string(let string):
                    return string
                case .object(let description):
                    return description.plainText
                }
            }
        }

        /// 获取纯文本描述（去除格式代码）
        var plainText: String {
            var result = ""
            if let text = text {
                result += stripFormatCodes(text)
            }
            if let extra = extra {
                result += extra.map { $0.plainText }.joined()
            }
            return result
        }

        /// 去除 Minecraft 格式代码
        private func stripFormatCodes(_ text: String) -> String {
            // 移除 § 符号及其后的格式代码
            var result = text
            while let range = result.range(of: "§") {
                let startIndex = range.lowerBound
                let endIndex = result.index(startIndex, offsetBy: 2, limitedBy: result.endIndex) ?? result.endIndex
                result.removeSubrange(startIndex..<endIndex)
            }
            return result
        }
    }

    let version: Version?
    let players: Players?
    let description: Description
    let favicon: String? // Base64 编码的图标
    let modinfo: ModInfo? // Mod 信息（如果有）

    struct ModInfo: Codable {
        let type: String
        let modList: [Mod]?

        struct Mod: Codable {
            let modid: String
            let version: String
        }
    }
}

/// Minecraft Server List Ping 协议实现
/// 使用官方协议（1.7+）获取服务器信息
enum MinecraftServerPing {
    /// 使用 Server List Ping 协议获取服务器信息
    /// - Parameters:
    ///   - connectAddress: 实际连接的地址（SRV target 或原始地址）
    ///   - connectPort: 实际连接的端口（SRV port 或原始端口）
    ///   - originalAddress: 原始域名（用于 handshake）
    ///   - originalPort: 原始端口（用于 handshake）
    ///   - timeout: 超时时间（秒），默认 5 秒
    /// - Returns: 服务器信息，如果失败则返回 nil
    static func ping(
        connectAddress: String,
        connectPort: Int,
        originalAddress: String,
        originalPort: Int,
        timeout: TimeInterval = 5.0
    ) async -> MinecraftServerInfo? {
        // 创建 TCP 连接（使用 SRV target 和 port）
        let host = NWEndpoint.Host(connectAddress)
        let nwPort = NWEndpoint.Port(integerLiteral: UInt16(connectPort))
        let connection = NWConnection(host: host, port: nwPort, using: .tcp)

        return await withCheckedContinuation { (continuation: CheckedContinuation<MinecraftServerInfo?, Never>) in
            final class State: @unchecked Sendable {
                private let lock = NSLock()
                private var _hasResumed = false
                private var _isTimeout = false
                var receivedData = Data()
                private var _timeoutTask: DispatchWorkItem?

                var hasResumed: Bool {
                    lock.lock()
                    defer { lock.unlock() }
                    return _hasResumed
                }

                var isTimeout: Bool {
                    lock.lock()
                    defer { lock.unlock() }
                    return _isTimeout
                }

                func setResumed() -> Bool {
                    lock.lock()
                    defer { lock.unlock() }
                    if _hasResumed {
                        return false
                    }
                    _hasResumed = true
                    return true
                }

                func setTimeout() {
                    lock.lock()
                    defer { lock.unlock() }
                    _isTimeout = true
                }

                func setResumedAndTimeout() -> Bool {
                    lock.lock()
                    defer { lock.unlock() }
                    if _hasResumed {
                        return false
                    }
                    _hasResumed = true
                    _isTimeout = true
                    return true
                }

                func setTimeoutTask(_ task: DispatchWorkItem?) {
                    lock.lock()
                    defer { lock.unlock() }
                    _timeoutTask = task
                }

                func cancelTimeoutTask() {
                    lock.lock()
                    defer { lock.unlock() }
                    _timeoutTask?.cancel()
                    _timeoutTask = nil
                }
            }
            let state = State()

            // 设置超时
            let timeoutTask = DispatchWorkItem { [weak state] in
                guard let state = state else { return }
                if state.setResumedAndTimeout() {
                    connection.cancel()
                    continuation.resume(returning: nil)
                }
            }
            state.setTimeoutTask(timeoutTask)
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutTask)

            // 递归接收数据的函数
            func receiveData() {
                guard !state.hasResumed else { return }

                connection.receive(minimumIncompleteLength: 1, maximumLength: 65535) { data, _, isComplete, error in
                    guard !state.hasResumed else { return }

                    if error != nil {
                        if !state.isTimeout {
                            if state.setResumed() {
                                state.cancelTimeoutTask()
                                connection.cancel()
                                continuation.resume(returning: nil)
                            }
                        }
                        return
                    }

                    if let data = data, !data.isEmpty {
                        state.receivedData.append(data)

                        // 尝试解析响应
                        if let serverInfo = parseResponse(data: state.receivedData) {
                            if state.setResumed() {
                                state.cancelTimeoutTask()
                                connection.cancel()
                                continuation.resume(returning: serverInfo)
                            }
                        } else if isComplete {
                            // 数据接收完成但解析失败
                            if state.setResumed() {
                                state.cancelTimeoutTask()
                                Logger.shared.debug("解析服务器响应失败: \(connectAddress):\(connectPort)")
                                connection.cancel()
                                continuation.resume(returning: nil)
                            }
                        } else {
                            // 继续接收数据
                            receiveData()
                        }
                    } else if isComplete {
                        // 没有更多数据
                        if state.setResumed() {
                            state.cancelTimeoutTask()
                            connection.cancel()
                            continuation.resume(returning: nil)
                        }
                    }
                }
            }

            // 开始接收数据
            receiveData()

            // 设置连接状态变化回调
            connection.stateUpdateHandler = { [weak state] stateUpdate in
                guard let state = state else { return }
                guard !state.hasResumed else { return }

                switch stateUpdate {
                case .ready:
                    // 连接成功，发送握手包和状态请求包（使用原始地址和端口）
                    sendHandshakeAndStatusRequest(connection: connection, address: originalAddress, port: originalPort)
                case .failed(let error):
                    if !state.isTimeout {
                        if state.setResumed() {
                            state.cancelTimeoutTask()
                            Logger.shared.debug("服务器连接失败: \(connectAddress):\(connectPort) - \(error.localizedDescription)")
                            connection.cancel()
                            continuation.resume(returning: nil)
                        }
                    }
                case .waiting:
                    // 连接等待中，无需记录日志
                    break
                case .cancelled:
                    if !state.hasResumed && !state.isTimeout {
                        if state.setResumed() {
                            state.cancelTimeoutTask()
                            continuation.resume(returning: nil)
                        }
                    }
                default:
                    break
                }
            }

            // 启动连接
            connection.start(queue: DispatchQueue.global(qos: .userInitiated))
        }
    }

    /// 发送握手包和状态请求包
    private static func sendHandshakeAndStatusRequest(connection: NWConnection, address: String, port: Int) {
        var packetData = Data()

        // 1. 发送 Handshake 包（包ID 0x00）
        // 包ID: 0x00 (VarInt)
        packetData.append(encodeVarInt(0))

        // 协议版本: -1 (VarInt) - 表示状态查询
        packetData.append(encodeVarInt(-1))

        // 服务器地址 (String)
        packetData.append(encodeString(address))

        // 服务器端口 (Unsigned Short)
        let portBytes = withUnsafeBytes(of: UInt16(port).bigEndian) { Data($0) }
        packetData.append(portBytes)

        // 下一个状态: 1 (VarInt) - 表示状态
        packetData.append(encodeVarInt(1))

        // 发送握手包
        let handshakeLength = encodeVarInt(Int32(packetData.count))
        let handshakePacket = handshakeLength + packetData
        connection.send(content: handshakePacket, completion: .contentProcessed { error in
            if let error = error {
                Logger.shared.debug("发送握手包失败: \(error.localizedDescription)")
                return
            }

            // 2. 发送 Status Request 包（包ID 0x00）
            var statusRequestData = Data()
            statusRequestData.append(encodeVarInt(0)) // 包ID: 0x00

            let statusRequestLength = encodeVarInt(Int32(statusRequestData.count))
            let statusRequestPacket = statusRequestLength + statusRequestData
            connection.send(content: statusRequestPacket, completion: .contentProcessed { error in
                if let error = error {
                    Logger.shared.debug("发送状态请求包失败: \(error.localizedDescription)")
                }
            })
        })
    }

    /// 解析服务器响应
    private static func parseResponse(data: Data) -> MinecraftServerInfo? {
        var offset = 0

        guard data.count > offset else { return nil }

        // 读取数据包长度（VarInt）
        guard let (packetLength, lengthBytes) = decodeVarInt(data: data, offset: &offset) else {
            return nil
        }

        // 检查数据是否完整
        let totalLength = lengthBytes + Int(packetLength)
        guard data.count >= totalLength else {
            return nil // 数据不完整，继续等待
        }

        // 读取包ID（VarInt）
        guard let (packetId, _) = decodeVarInt(data: data, offset: &offset) else {
            return nil
        }

        // Status Response 包的包ID应该是 0x00
        guard packetId == 0 else {
            return nil
        }

        // 读取 JSON 字符串
        guard let (jsonString, _) = decodeString(data: data, offset: &offset) else {
            return nil
        }

        // 解析 JSON
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let serverInfo = try decoder.decode(MinecraftServerInfo.self, from: jsonData)
            return serverInfo
        } catch {
            // JSON 解析失败时记录日志（可能是协议不兼容）
            Logger.shared.debug("解析服务器 JSON 失败: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - VarInt 编码/解码

    /// 编码 VarInt
    private static func encodeVarInt(_ value: Int32) -> Data {
        var result = Data()
        var val = UInt32(bitPattern: value)

        while true {
            var byte = UInt8(val & 0x7F)
            val >>= 7
            if val != 0 {
                byte |= 0x80
            }
            result.append(byte)
            if val == 0 {
                break
            }
        }

        return result
    }

    /// 解码 VarInt
    private static func decodeVarInt(data: Data, offset: inout Int) -> (Int32, Int)? {
        guard offset < data.count else { return nil }

        var result: UInt32 = 0
        var shift = 0
        var bytesRead = 0

        while offset < data.count {
            let byte = data[offset]
            offset += 1
            bytesRead += 1

            result |= UInt32(byte & 0x7F) << shift

            if (byte & 0x80) == 0 {
                break
            }

            shift += 7
            if shift >= 32 {
                return nil // VarInt 溢出
            }
        }

        return (Int32(bitPattern: result), bytesRead)
    }

    // MARK: - String 编码/解码

    /// 编码字符串（UTF-8，前面加上 VarInt 长度）
    private static func encodeString(_ string: String) -> Data {
        guard let utf8Data = string.data(using: .utf8) else {
            return encodeVarInt(0) // 空字符串
        }

        var result = Data()
        result.append(encodeVarInt(Int32(utf8Data.count)))
        result.append(utf8Data)
        return result
    }

    /// 解码字符串
    private static func decodeString(data: Data, offset: inout Int) -> (String, Int)? {
        guard let (length, lengthBytes) = decodeVarInt(data: data, offset: &offset) else {
            return nil
        }

        guard length >= 0 else { return nil }
        guard offset + Int(length) <= data.count else {
            // 数据不完整，恢复 offset
            offset -= lengthBytes
            return nil
        }

        let stringData = data.subdata(in: offset..<(offset + Int(length)))
        offset += Int(length)

        guard let string = String(data: stringData, encoding: .utf8) else {
            return nil
        }

        return (string, lengthBytes + Int(length))
    }
}
