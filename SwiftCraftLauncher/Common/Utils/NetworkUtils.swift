//
//  NetworkUtils.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/20.
//

import Foundation
import Network

/// 服务器连接状态
enum ServerConnectionStatus {
    case unknown
    case checking
    case success(serverInfo: MinecraftServerInfo?)
    case timeout
    case failed
}

/// 解析后的服务器地址信息
struct ResolvedServerAddress {
    let address: String  // 实际连接的地址（SRV target 或原始地址）
    let port: Int        // 实际连接的端口（SRV port 或原始端口）
    let originalAddress: String  // 原始域名（用于 handshake）
    let originalPort: Int        // 原始端口（用于 handshake）
}

/// 网络工具类
/// 提供网络连接检测等功能
enum NetworkUtils {
    /// 智能解析服务器地址
    /// 根据用户输入自动判断端口，如果没有端口则查询 SRV 记录
    /// - Parameter input: 用户输入的地址（可能包含端口，如 "example.com:25565" 或 "example.com"）
    /// - Returns: 解析后的地址和端口（包含原始地址信息）
    static func resolveServerAddress(_ input: String) async -> ResolvedServerAddress {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        var originalAddress = trimmed
        var originalPort = 25565

        // 检查是否包含端口
        if let colonIndex = trimmed.lastIndex(of: ":") {
            // 检查冒号后的内容是否为数字（端口）
            let afterColon = String(trimmed[trimmed.index(after: colonIndex)...])
            if let port = Int(afterColon), port > 0 && port <= 65535 {
                // 包含有效端口，直接使用
                let address = String(trimmed[..<colonIndex])
                originalAddress = address
                originalPort = port
                return ResolvedServerAddress(
                    address: address,
                    port: port,
                    originalAddress: originalAddress,
                    originalPort: originalPort
                )
            }
        }

        // 不包含端口，查询 SRV 记录
        if let srvResult = await querySRVRecord(for: trimmed) {
            // SRV 记录返回的是连接地址，原始地址是输入的域名
            return ResolvedServerAddress(
                address: srvResult.address,
                port: srvResult.port,
                originalAddress: trimmed,
                originalPort: 25565  // 默认端口
            )
        }

        // 没有 SRV 记录，使用默认端口 25565
        return ResolvedServerAddress(
            address: trimmed,
            port: 25565,
            originalAddress: trimmed,
            originalPort: 25565
        )
    }

    /// 查询 Minecraft SRV 记录
    /// - Parameter domain: 域名
    /// - Returns: SRV 记录中的地址和端口（仅连接信息），如果没有则返回 nil
    private static func querySRVRecord(for domain: String) async -> (address: String, port: Int)? {
        let srvName = "_minecraft._tcp.\(domain)"

        // 使用系统的 dig 命令查询 SRV 记录（更简单可靠）
        // 注意：不能在 async 上下文里用 `waitUntilExit()` 同步阻塞（若调用者在主线程/主 Actor 会卡 UI）。
        guard let output = await runDigShortSRVQuery(srvName: srvName) else { return nil }

        // 解析 SRV 记录格式: priority weight port target
        // 例如: "5 0 25565 mc.example.com."
        let lines = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
        guard let firstLine = lines.first, !firstLine.isEmpty else {
            return nil
        }

        let components = firstLine.split(separator: " ").map(String.init)
        guard components.count >= 4 else {
            return nil
        }

        guard let port = Int(components[2]), port > 0 && port <= 65535 else {
            return nil
        }

        var target = components[3]
        // 移除末尾的点（如果有）
        if target.hasSuffix(".") {
            target = String(target.dropLast())
        }

        return (address: target, port: port)
    }

    /// 异步执行 `dig +short SRV <srvName>` 并返回 stdout 文本
    private static func runDigShortSRVQuery(srvName: String) async -> String? {
        await withCheckedContinuation { continuation in
            final class ResumeGuard: @unchecked Sendable {
                private let lock = NSLock()
                private var didResume = false
                private let continuation: CheckedContinuation<String?, Never>

                init(continuation: CheckedContinuation<String?, Never>) {
                    self.continuation = continuation
                }

                func resumeOnce(_ value: String?) {
                    lock.lock()
                    defer { lock.unlock() }
                    guard !didResume else { return }
                    didResume = true
                    continuation.resume(returning: value)
                }
            }
            let resumeGuard = ResumeGuard(continuation: continuation)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/dig")
            process.arguments = ["+short", "SRV", srvName]

            let stdoutPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = Pipe()

            process.terminationHandler = { proc in
                let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                try? stdoutPipe.fileHandleForReading.close()

                guard proc.terminationStatus == 0 else {
                    Logger.shared.debug("dig 查询失败，退出状态: \(proc.terminationStatus)")
                    resumeGuard.resumeOnce(nil)
                    return
                }

                guard let output = String(data: data, encoding: .utf8) else {
                    resumeGuard.resumeOnce(nil)
                    return
                }

                resumeGuard.resumeOnce(output)
            }

            do {
                try process.run()
            } catch {
                Logger.shared.debug("无法启动 dig 进程: \(error.localizedDescription)")
                resumeGuard.resumeOnce(nil)
            }
        }
    }
    /// 检测服务器连接状态（使用 Minecraft Server List Ping 协议）
    /// - Parameters:
    ///   - address: 服务器地址
    ///   - port: 服务器端口
    ///   - timeout: 超时时间（秒），默认 5 秒
    /// - Returns: 连接状态，成功时包含服务器信息
    static func checkServerConnectionStatus(
        address: String,
        port: Int,
        timeout: TimeInterval = 5.0
    ) async -> ServerConnectionStatus {
        // 解析服务器地址（查询 SRV 记录）
        let resolved = await resolveServerAddress(address)

        // 使用 Minecraft Server List Ping 协议获取服务器信息
        // 使用 SRV target + port 建立连接，但 handshake 使用原始域名
        if let serverInfo = await MinecraftServerPing.ping(
            connectAddress: resolved.address,
            connectPort: resolved.port,
            originalAddress: resolved.originalAddress,
            originalPort: resolved.originalPort,
            timeout: timeout
        ) {
            return .success(serverInfo: serverInfo)
        } else {
            return .timeout
        }
    }

    /// 检测服务器连接是否可用（兼容旧接口）
    /// - Parameters:
    ///   - address: 服务器地址
    ///   - port: 服务器端口
    ///   - timeout: 超时时间（秒），默认 5 秒
    /// - Returns: 检测结果，true 表示连接成功，false 表示连接失败
    /// - Throws: 检测过程中的错误
    static func checkServerConnection(
        address: String,
        port: Int,
        timeout: TimeInterval = 5.0
    ) async throws -> Bool {
        let status = await checkServerConnectionStatus(address: address, port: port, timeout: timeout)
        if case .success = status {
            return true
        }
        return false
    }
}
