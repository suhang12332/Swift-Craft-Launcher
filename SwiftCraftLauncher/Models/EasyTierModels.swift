import Foundation

/// EasyTier 网络状态
enum EasyTierNetworkStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.connected, .connected):
            return true
        case let (.error(lhsMessage), .error(rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

/// EasyTier 房间信息
struct EasyTierRoom {
    /// 房间码（格式：U/NNNN-NNNN-SSSS-SSSS）
    let roomCode: String

    /// 网络名称（scaffolding-mc-NNNN-NNNN）
    let networkName: String

    /// 网络密钥（SSSS-SSSS）
    let networkSecret: String

    /// 主机名（scaffolding-mc-server-{port}）
    let hostName: String

    /// 网络状态
    var status: EasyTierNetworkStatus

    /// 进程 ID（如果正在运行）
    var processID: Int32?

    init(roomCode: String) {
        self.roomCode = roomCode

        // 从房间码提取网络信息
        if let info = RoomCodeGenerator.extractNetworkInfo(from: roomCode) {
            self.networkName = info.networkName
            self.networkSecret = info.networkSecret
        } else {
            // 如果提取失败，使用默认值（不应该发生）
            self.networkName = "scaffolding-mc-0000-0000"
            self.networkSecret = "0000-0000"
        }

        // 生成合法的主机名（端口范围：1024 < port <= 65535）
        let port = generateValidPort()
        self.hostName = "scaffolding-mc-server-\(port)"

        self.status = .disconnected
        self.processID = nil
    }
}

/// 生成合法的端口号
/// - Returns: 端口号，范围：1024 < port <= 65535
private func generateValidPort() -> UInt16 {
    // 生成范围：1025 到 65535（包含）
    let minPort: UInt16 = 1025
    let maxPort: UInt16 = 65535
    let port = UInt16.random(in: minPort...maxPort)
    return port
}

/// EasyTier 对等节点信息
struct EasyTierPeer: Identifiable {
    let id = UUID()

    /// IPv4 地址和子网
    let ipv4: String

    /// 主机名
    let hostname: String

    /// 成本类型（Local, p2p等）
    let cost: String

    /// 延迟（毫秒），如果为 "-" 则为 nil
    let latency: Double?

    /// 丢包率（百分比），如果为 "-" 则为 nil
    let packetLoss: Double?

    /// 接收数据量
    let rx: String

    /// 发送数据量
    let tx: String

    /// 隧道类型（tcp, udp等）
    let tunnel: String

    /// NAT 类型
    let nat: String

    /// 版本号
    let version: String

    /// 从表格行解析对等节点信息
    /// - Parameter line: 表格行（去除管道符后的字段）
    init?(fromTableLine line: String) {
        // 分割行，按 | 分隔并去除空白
        let fields = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        // 应该有至少9个字段：ipv4, hostname, cost, lat(ms), loss, rx, tx, tunnel, NAT, version
        guard fields.count >= 10 else {
            return nil
        }

        self.ipv4 = fields[0]
        self.hostname = fields[1]
        self.cost = fields[2]

        // 解析延迟
        if let latencyStr = Double(fields[3]), latencyStr > 0 {
            self.latency = latencyStr
        } else {
            self.latency = nil
        }

        // 解析丢包率（格式：0.0%）
        if fields[4].hasSuffix("%"), let lossValue = Double(fields[4].replacingOccurrences(of: "%", with: "")) {
            self.packetLoss = lossValue
        } else {
            self.packetLoss = nil
        }

        self.rx = fields[5]
        self.tx = fields[6]
        self.tunnel = fields[7]
        self.nat = fields[8]
        self.version = fields[9]
    }
}
