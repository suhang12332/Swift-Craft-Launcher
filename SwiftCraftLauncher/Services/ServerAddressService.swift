//
//  ServerAddressService.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/20.
//

import Foundation
import CryptoKit

/// 服务器地址服务
/// 负责读取和管理 Minecraft 游戏的服务器地址列表
@MainActor
class ServerAddressService {
    static let shared = ServerAddressService()
    
    private init() {}
    
    /// 从游戏目录读取服务器地址列表（仅从 servers.dat 读取）
    /// - Parameter gameName: 游戏名称
    /// - Returns: 服务器地址列表
    func loadServerAddresses(for gameName: String) async throws -> [ServerAddress] {
        let profileDir = AppPaths.profileDirectory(gameName: gameName)
        let serversDatURL = profileDir.appendingPathComponent("servers.dat")
        
        // 检查 servers.dat 文件是否存在
        guard FileManager.default.fileExists(atPath: serversDatURL.path) else {
            Logger.shared.debug("servers.dat 文件不存在: \(serversDatURL.path)")
            return []
        }
        
        Logger.shared.debug("开始读取 servers.dat: \(serversDatURL.path)")
        
        do {
            let data = try Data(contentsOf: serversDatURL)
            Logger.shared.debug("servers.dat 文件大小: \(data.count) 字节")
            let servers = try parseServersDat(data: data)
            Logger.shared.debug("成功解析 \(servers.count) 个服务器")
            return servers
        } catch {
            Logger.shared.warning("解析服务器地址 servers.dat 文件失败: \(error.localizedDescription)")
            // 解析失败时返回空数组，而不是抛出错误
            return []
        }
    }
    
    /// 解析 servers.dat 文件（NBT 格式）
    /// - Parameter data: 文件数据
    /// - Returns: 服务器地址列表
    /// - Throws: 解析错误
    private func parseServersDat(data: Data) throws -> [ServerAddress] {
        let parser = NBTParser(data: data)
        let nbtData = try parser.parse()
        
        Logger.shared.debug("NBT 解析完成，根标签键: \(nbtData.keys.joined(separator: ", "))")
        
        // servers.dat 结构：
        // TAG_Compound("")
        //   TAG_List("servers")
        //     TAG_Compound
        //       TAG_String("name") - 服务器名称
        //       TAG_String("ip") - 服务器地址（可能包含端口，格式为 "ip:port"）
        //       TAG_Byte("hidden") - 是否隐藏（可选，0 或 1）
        //       TAG_String("icon") - 服务器图标（可选，Base64 编码）
        //       TAG_Byte("acceptTextures") - 是否接受纹理（可选，0 或 1）
        
        guard let serversList = nbtData["servers"] as? [[String: Any]] else {
            Logger.shared.debug("未找到 servers 列表，或类型不匹配")
            // 如果没有 servers 列表，返回空数组
            return []
        }
        
        Logger.shared.debug("找到 \(serversList.count) 个服务器条目")
        
        var servers: [ServerAddress] = []
        
        for serverData in serversList {
            guard let name = serverData["name"] as? String,
                  let ip = serverData["ip"] as? String else {
                // 跳过缺少必要字段的服务器
                continue
            }
            
            // 解析 IP 地址和端口
            let (address, port) = parseIPAndPort(ip)
            
            // 读取可选字段
            // NBT Byte 类型在解析后可能是 Int8 或其他整数类型
            let hidden: Bool
            if let hiddenValue = serverData["hidden"] as? Int8 {
                hidden = hiddenValue != 0
            } else if let hiddenValue = serverData["hidden"] as? Int {
                hidden = hiddenValue != 0
            } else {
                hidden = false
            }
            
            let icon = serverData["icon"] as? String
            
            let acceptTextures: Bool
            // 读取 preventsChatReports（官方字段）
            if let preventsValue = serverData["preventsChatReports"] as? Int8 {
                acceptTextures = preventsValue != 0
            } else if let preventsValue = serverData["preventsChatReports"] as? Int {
                acceptTextures = preventsValue != 0
            } else {
                acceptTextures = false
            }
            
            // 使用服务器内容的哈希值生成稳定的 ID，确保重新读取后 ID 保持一致
            let stableId = generateStableServerId(name: name, address: address, port: port)
            
            let server = ServerAddress(
                id: stableId,
                name: name,
                address: address,
                port: port,
                hidden: hidden,
                icon: icon,
                acceptTextures: acceptTextures
            )
            
            servers.append(server)
        }
        
        return servers
    }
    
    /// 解析 IP 地址和端口
    /// - Parameter ipString: IP 字符串，格式为 "ip" 或 "ip:port"
    /// - Returns: (地址, 端口) 元组，端口为0表示未设置
    private func parseIPAndPort(_ ipString: String) -> (String, Int) {
        let components = ipString.split(separator: ":")
        
        if components.count == 2,
           let port = Int(components[1]),
           port > 0 {
            return (String(components[0]), port)
        }
        
        // 如果没有端口或端口无效，返回0表示未设置
        return (ipString, 0)
    }
    
    /// 生成稳定的服务器 ID（基于服务器内容）
    /// - Parameters:
    ///   - name: 服务器名称
    ///   - address: 服务器地址
    ///   - port: 服务器端口
    /// - Returns: 稳定的 UUID 字符串
    private func generateStableServerId(name: String, address: String, port: Int) -> String {
        // 使用服务器名称、地址和端口生成稳定的标识符
        let content = "\(name)|\(address)|\(port)"
        guard let data = content.data(using: .utf8) else {
            // 如果编码失败，使用简单的哈希作为后备
            return UUID().uuidString
        }
        
        // 使用 SHA256 哈希生成稳定的 UUID
        let hash = SHA256.hash(data: data)
        var bytes = Array(hash.prefix(16)) // 使用前 16 字节
        
        // 设置为 UUID v5 格式（基于 SHA-1 命名空间，这里使用 SHA256 的前 16 字节）
        bytes[6] = (bytes[6] & 0x0F) | 0x50 // 版本 5
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // RFC 4122 variant
        
        let uuid = bytes.withUnsafeBytes { UUID(uuid: $0.load(as: uuid_t.self)) }
        return uuid.uuidString
    }
    
    /// 保存服务器地址列表到游戏目录（保存为 servers.dat，NBT 格式）
    /// - Parameters:
    ///   - servers: 服务器地址列表
    ///   - gameName: 游戏名称
    /// - Throws: 保存错误
    func saveServerAddresses(_ servers: [ServerAddress], for gameName: String) async throws {
        let serversDatURL = AppPaths.profileDirectory(gameName: gameName)
            .appendingPathComponent("servers.dat")
        
        Logger.shared.debug("开始保存服务器地址列表到: \(serversDatURL.path)")
        
        // 构建 NBT 数据结构
        // servers.dat 结构：
        // TAG_Compound("")
        //   TAG_List("servers")
        //     TAG_Compound
        //       TAG_String("name") - 服务器名称
        //       TAG_String("ip") - 服务器地址（格式为 "ip:port"）
        //       TAG_Byte("hidden") - 是否隐藏（0 或 1）
        //       TAG_String("icon") - 服务器图标（可选，Base64 编码）
        //       TAG_Byte("acceptTextures") - 是否接受纹理（0 或 1）
        
        var serversList: [[String: Any]] = []
        
        for server in servers {
            var serverData: [String: Any] = [:]
            // 按照标准顺序保存字段
            serverData["name"] = server.name
            serverData["hidden"] = server.hidden ? Int8(1) : Int8(0)
            serverData["preventsChatReports"] = server.acceptTextures ? Int8(1) : Int8(0)
            // 如果端口为0，只保存地址，不保存端口
            if server.port > 0 {
                serverData["ip"] = "\(server.address):\(server.port)"
            } else {
                serverData["ip"] = server.address
            }
            
            // icon 字段只在有值时保存
            if let icon = server.icon, !icon.isEmpty {
                serverData["icon"] = icon
            }
            
            serversList.append(serverData)
        }
        
        let nbtData: [String: Any] = [
            "servers": serversList
        ]
        
        // 编码为 NBT 格式（不使用压缩，Minecraft 需要未压缩的 NBT 文件）
        let encodedData = try NBTParser.encode(nbtData, compress: false)
        
        // 确保目录存在
        let directory = serversDatURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // 写入文件
        try encodedData.write(to: serversDatURL)
        
        Logger.shared.debug("成功保存 \(servers.count) 个服务器地址到 servers.dat")
    }
}

