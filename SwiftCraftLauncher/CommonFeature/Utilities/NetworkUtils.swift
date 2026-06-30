//
//  NetworkUtils.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// Provides Minecraft server address resolution and connectivity checks.
import Foundation
import Network

/// The status of a server connection check.
enum ServerConnectionStatus {
    case unknown
    case checking
    case success(serverInfo: MinecraftServerInfo?)
    case timeout
    case failed
}

/// A resolved server address containing both the connection target and the original user input.
struct ResolvedServerAddress {
    let address: String
    let port: Int
    let originalAddress: String
    let originalPort: Int
}

/// Provides network utilities for Minecraft server address resolution and connectivity checks.
enum NetworkUtils {
    /// Resolves a server address using the default Minecraft port.
    /// - Parameter input: The user-provided address string, optionally including a port.
    /// - Returns: The resolved address and port information.
    static func resolveServerAddress(_ input: String) async -> ResolvedServerAddress {
        await resolveServerAddress(input, explicitPort: 25565)
    }

    /// Resolves a server address, preferring an explicit port over SRV record lookup.
    /// - Parameters:
    ///   - input: The user-provided address string, optionally including a port.
    ///   - explicitPort: The port specified by the caller.
    /// - Returns: The resolved address and port information.
    static func resolveServerAddress(_ input: String, explicitPort: Int) async -> ResolvedServerAddress {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        var originalAddress = trimmed
        var originalPort = 25565

        if let colonIndex = trimmed.lastIndex(of: ":") {
            let afterColon = String(trimmed[trimmed.index(after: colonIndex)...])
            if let port = Int(afterColon), port > 0, port <= 65535 {
                let address = String(trimmed[..<colonIndex])
                originalAddress = address
                originalPort = port
                return ResolvedServerAddress(
                    address: address,
                    port: port,
                    originalAddress: originalAddress,
                    originalPort: originalPort,
                )
            }
        }

        if explicitPort > 0, explicitPort <= 65535, explicitPort != 25565 {
            return ResolvedServerAddress(
                address: trimmed,
                port: explicitPort,
                originalAddress: trimmed,
                originalPort: explicitPort,
            )
        }

        if let srvResult = await querySRVRecord(for: trimmed) {
            return ResolvedServerAddress(
                address: srvResult.address,
                port: srvResult.port,
                originalAddress: trimmed,
                originalPort: 25565,
            )
        }

        return ResolvedServerAddress(
            address: trimmed,
            port: 25565,
            originalAddress: trimmed,
            originalPort: 25565,
        )
    }

    /// Queries the Minecraft SRV record for the specified domain.
    /// - Parameter domain: The domain to query.
    /// - Returns: The target address and port from the SRV record, or `nil` if not found.
    private static func querySRVRecord(for domain: String) async -> (address: String, port: Int)? {
        let srvName = "_minecraft._tcp.\(domain)"

        guard let output = await runDigShortSRVQuery(srvName: srvName) else { return nil }

        let lines = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
        guard let firstLine = lines.first, !firstLine.isEmpty else {
            return nil
        }

        let components = firstLine.split(separator: " ").map(String.init)
        guard components.count >= 4 else {
            return nil
        }

        guard let port = Int(components[2]), port > 0, port <= 65535 else {
            return nil
        }

        var target = components[3]
        if target.hasSuffix(".") {
            target = String(target.dropLast())
        }

        return (address: target, port: port)
    }

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

    /// Checks a Minecraft server's connection status using the Server List Ping protocol.
    /// - Parameters:
    ///   - address: The server address.
    ///   - port: The server port.
    ///   - timeout: The connection timeout in seconds. Defaults to 5.
    /// - Returns: The connection status, which includes server info on success.
    static func checkServerConnectionStatus(
        address: String,
        port: Int,
        timeout: TimeInterval = 5.0,
    ) async -> ServerConnectionStatus {
        let resolved = await resolveServerAddress(address, explicitPort: port)

        if let serverInfo = await MinecraftServerPing.ping(
            connectAddress: resolved.address,
            connectPort: resolved.port,
            originalAddress: resolved.originalAddress,
            originalPort: resolved.originalPort,
            timeout: timeout,
        ) {
            return .success(serverInfo: serverInfo)
        } else {
            return .timeout
        }
    }

    /// Checks whether a Minecraft server is reachable.
    /// - Parameters:
    ///   - address: The server address.
    ///   - port: The server port.
    ///   - timeout: The connection timeout in seconds. Defaults to 5.
    /// - Returns: `true` if the server responded successfully.
    static func checkServerConnection(
        address: String,
        port: Int,
        timeout: TimeInterval = 5.0,
    ) async throws -> Bool {
        let status = await checkServerConnectionStatus(address: address, port: port, timeout: timeout)
        if case .success = status {
            return true
        }
        return false
    }
}
