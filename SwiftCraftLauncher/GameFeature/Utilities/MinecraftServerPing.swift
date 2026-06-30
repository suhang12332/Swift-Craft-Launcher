//
//  MinecraftServerPing.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
@preconcurrency import Dispatch
@preconcurrency import Network

/// Represents information about a Minecraft server.
struct MinecraftServerInfo: Codable {
    /// The server version information.
    struct Version: Codable {
        let name: String
        let `protocol`: Int?
    }

    /// The player information.
    struct Players: Codable {
        let max: Int
        let online: Int
        let sample: [Player]?

        struct Player: Codable {
            let name: String
            let id: String?
        }
    }

    /// The server description (MOTD).
    struct Description: Codable {
        let text: String?
        let extra: [DescriptionElement]?

        /// A description element that can be either a string or a nested Description object.
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

        /// Returns the plain text description with formatting codes removed.
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

        /// Removes Minecraft formatting codes from the text.
        private func stripFormatCodes(_ text: String) -> String {
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
    let favicon: String? // Base64-encoded server icon.
    let modinfo: ModInfo? // Mod information, if available.

    struct ModInfo: Codable {
        let type: String
        let modList: [Mod]?

        struct Mod: Codable {
            let modid: String
            let version: String
        }
    }
}

/// Implements the Minecraft Server List Ping protocol to retrieve server information.
enum MinecraftServerPing {
    /// Pings a Minecraft server using the Server List Ping protocol.
    /// - Parameters:
    ///   - connectAddress: The actual connection address (SRV target or original address).
    ///   - connectPort: The actual connection port (SRV port or original port).
    ///   - originalAddress: The original domain name (used for handshake).
    ///   - originalPort: The original port (used for handshake).
    ///   - timeout: The timeout in seconds. Defaults to 5.0.
    /// - Returns: The server information, or `nil` if the ping fails.
    static func ping(
        connectAddress: String,
        connectPort: Int,
        originalAddress: String,
        originalPort: Int,
        timeout: TimeInterval = 5.0
    ) async -> MinecraftServerInfo? {
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

            let timeoutTask = DispatchWorkItem { [weak state] in
                guard let state = state else { return }
                if state.setResumedAndTimeout() {
                    connection.cancel()
                    continuation.resume(returning: nil)
                }
            }
            state.setTimeoutTask(timeoutTask)
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutTask)

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

                        if let serverInfo = parseResponse(data: state.receivedData) {
                            if state.setResumed() {
                                state.cancelTimeoutTask()
                                connection.cancel()
                                continuation.resume(returning: serverInfo)
                            }
                        } else if isComplete {
                            if state.setResumed() {
                                state.cancelTimeoutTask()
                                Logger.shared.debug("解析服务器响应失败: \(connectAddress):\(connectPort)")
                                connection.cancel()
                                continuation.resume(returning: nil)
                            }
                        } else {
                            receiveData()
                        }
                    } else if isComplete {
                        if state.setResumed() {
                            state.cancelTimeoutTask()
                            connection.cancel()
                            continuation.resume(returning: nil)
                        }
                    }
                }
            }

            receiveData()

            connection.stateUpdateHandler = { [weak state] stateUpdate in
                guard let state = state else { return }
                guard !state.hasResumed else { return }

                switch stateUpdate {
                case .ready:
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

            connection.start(queue: DispatchQueue.global(qos: .userInitiated))
        }
    }

    /// Sends the handshake and status request packets to the server.
    private static func sendHandshakeAndStatusRequest(connection: NWConnection, address: String, port: Int) {
        var packetData = Data()

        packetData.append(encodeVarInt(0))
        packetData.append(encodeVarInt(-1))
        packetData.append(encodeString(address))

        let portBytes = withUnsafeBytes(of: UInt16(port).bigEndian) { Data($0) }
        packetData.append(portBytes)

        packetData.append(encodeVarInt(1))

        let handshakeLength = encodeVarInt(Int32(packetData.count))
        let handshakePacket = handshakeLength + packetData
        connection.send(content: handshakePacket, completion: .contentProcessed { error in
            if let error = error {
                Logger.shared.debug("发送握手包失败: \(error.localizedDescription)")
                return
            }

            var statusRequestData = Data()
            statusRequestData.append(encodeVarInt(0))

            let statusRequestLength = encodeVarInt(Int32(statusRequestData.count))
            let statusRequestPacket = statusRequestLength + statusRequestData
            connection.send(content: statusRequestPacket, completion: .contentProcessed { error in
                if let error = error {
                    Logger.shared.debug("发送状态请求包失败: \(error.localizedDescription)")
                }
            })
        })
    }

    /// Parses the server response data into a `MinecraftServerInfo` structure.
    private static func parseResponse(data: Data) -> MinecraftServerInfo? {
        var offset = 0

        guard data.count > offset else { return nil }

        guard let (packetLength, lengthBytes) = decodeVarInt(data: data, offset: &offset) else {
            return nil
        }

        let totalLength = lengthBytes + Int(packetLength)
        guard data.count >= totalLength else {
            return nil
        }

        guard let (packetId, _) = decodeVarInt(data: data, offset: &offset) else {
            return nil
        }

        guard packetId == 0 else {
            return nil
        }

        guard let (jsonString, _) = decodeString(data: data, offset: &offset) else {
            return nil
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let serverInfo = try decoder.decode(MinecraftServerInfo.self, from: jsonData)
            return serverInfo
        } catch {
            Logger.shared.debug("解析服务器 JSON 失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// Encodes an integer as a VarInt.
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

    /// Decodes a VarInt from data at the specified offset.
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
                return nil
            }
        }

        return (Int32(bitPattern: result), bytesRead)
    }

    /// Encodes a string with a VarInt length prefix.
    private static func encodeString(_ string: String) -> Data {
        guard let utf8Data = string.data(using: .utf8) else {
            return encodeVarInt(0)
        }

        var result = Data()
        result.append(encodeVarInt(Int32(utf8Data.count)))
        result.append(utf8Data)
        return result
    }

    /// Decodes a string with a VarInt length prefix from data at the specified offset.
    private static func decodeString(data: Data, offset: inout Int) -> (String, Int)? {
        guard let (length, lengthBytes) = decodeVarInt(data: data, offset: &offset) else {
            return nil
        }

        guard length >= 0 else { return nil }
        guard offset + Int(length) <= data.count else {
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
