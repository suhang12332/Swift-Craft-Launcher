import Foundation

/// 玩家信息模型
/// 用于存储和管理玩家的基本信息、游戏记录等
struct Player: Identifiable, Codable, Equatable {
    /// 玩家唯一标识符
    let id: String

    /// 玩家名称
    let name: String
    /// 是否为在线账号
    var isOnlineAccount: Bool
    /// 玩家头像路径或URL
    let avatarName: String
    var authXuid: String
    var authAccessToken: String
    /// Refresh Token（用于自动刷新访问令牌）
    var authRefreshToken: String
    /// 账号创建时间
    let createdAt: Date

    /// 最后游玩时间
    var lastPlayed: Date

    /// 是否为当前选中的玩家
    var isCurrent: Bool

    /// 游戏记录字典
    /// - Key: 游戏ID或名称
    /// - Value: 对应的游戏记录
    var gameRecords: [String: PlayerGameRecord]

    /// 计算总游戏时间
    var totalPlayTime: TimeInterval {
        gameRecords.values.reduce(0) { $0 + $1.playTime }
    }

    /// 获取最近游玩的游戏列表
    /// 按最后游玩时间降序排序
    var recentlyPlayedGames: [PlayerGameRecord] {
        gameRecords.values.sorted { $0.lastPlayed > $1.lastPlayed }
    }

        /// 初始化玩家信息
    /// - Parameters:
    ///   - name: 玩家名称
    ///   - uuid: 玩家UUID，如果为nil则生成离线UUID
    ///   - createdAt: 创建时间，默认当前时间
    ///   - lastPlayed: 最后游玩时间，默认当前时间
    ///   - isOnlineAccount: 是否在线账号，默认false
    ///   - isCurrent: 是否当前玩家，默认false
    ///   - gameRecords: 游戏记录，默认空字典
    /// - Throws: 如果生成玩家ID失败则抛出错误
    init(
        name: String,
        uuid: String? = nil,
        isOnlineAccount: Bool,
        avatarName: String,
        authXuid: String,
        authAccessToken: String,
        authRefreshToken: String = "",
        createdAt: Date = Date(),
        lastPlayed: Date = Date(),
        isCurrent: Bool = false,
        gameRecords: [String: PlayerGameRecord] = [:]
    ) throws {
        // 如果提供了UUID则使用，否则生成离线UUID
        if let providedUUID = uuid {
            self.id = providedUUID
        } else {
            self.id = try PlayerUtils.generateOfflineUUID(for: name)
        }
        self.name = name
        self.isOnlineAccount = isOnlineAccount
        self.avatarName = isOnlineAccount ? avatarName : PlayerUtils.avatarName(for: self.id) ?? "steve"
        self.createdAt = createdAt
        self.lastPlayed = lastPlayed
        self.isCurrent = isCurrent
        self.gameRecords = gameRecords
        self.authAccessToken = authAccessToken
        self.authRefreshToken = authRefreshToken
        self.authXuid = authXuid
    }

    /// 更新指定游戏的记录
    /// - Parameters:
    ///   - gameId: 游戏ID
    ///   - record: 新的游戏记录
    mutating func updateGameRecord(gameId: String, record: PlayerGameRecord) {
        gameRecords[gameId] = record
        lastPlayed = Date()
    }

    /// 获取指定游戏的记录
    /// - Parameter gameId: 游戏ID
    /// - Returns: 游戏记录，如果不存在则返回nil
    func getGameRecord(for gameId: String) -> PlayerGameRecord? {
        return gameRecords[gameId]
    }
}

/// 玩家游戏记录模型
/// 用于记录玩家在特定游戏中的游玩信息
struct PlayerGameRecord: Identifiable, Codable, Equatable {
    /// 记录唯一标识符
    let id: UUID

    /// 关联的玩家ID
    let playerId: UUID

    /// 关联的游戏版本ID
    let gameVersionId: UUID

    /// 首次游玩时间
    let startPlayTime: Date

    /// 累计游玩时间（秒）
    var playTime: TimeInterval

    /// 最后游玩时间
    var lastPlayed: Date

    /// 游戏版本号
    let gameVersion: String

    /// 格式化后的游戏时间
    /// 格式：X小时Y分钟
    var formattedPlayTime: String {
        let hours = Int(playTime) / 3600
        let minutes = (Int(playTime) % 3600) / 60
        return String(format: "time.hours_minutes".localized(), hours, minutes)
    }

    /// 判断游戏是否正在运行
    /// 如果最后游玩时间在5分钟内，则认为正在运行
    var isPlaying: Bool {
        return lastPlayed.timeIntervalSinceNow > -300
    }

    /// 初始化游戏记录
    /// - Parameters:
    ///   - id: 记录ID，默认生成新的UUID
    ///   - playerId: 玩家ID
    ///   - gameVersionId: 游戏版本ID
    ///   - startPlayTime: 开始时间，默认当前时间
    ///   - playTime: 游玩时间，默认0
    ///   - lastPlayed: 最后游玩时间，默认当前时间
    ///   - gameVersion: 游戏版本号
    init(
        id: UUID = UUID(),
        playerId: UUID,
        gameVersionId: UUID,
        startPlayTime: Date = Date(),
        playTime: TimeInterval = 0,
        lastPlayed: Date = Date(),
        gameVersion: String
    ) {
        self.id = id
        self.playerId = playerId
        self.gameVersionId = gameVersionId
        self.startPlayTime = startPlayTime
        self.playTime = playTime
        self.lastPlayed = lastPlayed
        self.gameVersion = gameVersion
    }

    /// 更新游戏时间
    /// - Parameter additionalTime: 新增的游戏时间（秒）
    mutating func updatePlayTime(_ additionalTime: TimeInterval) {
        playTime += additionalTime
        lastPlayed = Date()
    }

    /// 重置游戏时间
    /// 将游玩时间设为0，并更新最后游玩时间
    mutating func resetPlayTime() {
        playTime = 0
        lastPlayed = Date()
    }
}
