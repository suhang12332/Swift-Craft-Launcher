import Foundation

// MARK: - 世界信息模型
struct WorldInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let path: URL
    let lastPlayed: Date?
    let gameMode: String?
    let difficulty: String?
    /// 是否极限模式（不同版本字段位置不同，可能无法解析时为 nil）
    let hardcore: Bool?
    /// 是否允许作弊/指令（allowCommands），可能无法解析时为 nil
    let cheats: Bool?
    let version: String?
    let seed: Int64?

    init(
        name: String,
        path: URL,
        lastPlayed: Date? = nil,
        gameMode: String? = nil,
        difficulty: String? = nil,
        hardcore: Bool? = nil,
        cheats: Bool? = nil,
        version: String? = nil,
        seed: Int64? = nil
    ) {
        self.id = path.lastPathComponent
        self.name = name
        self.path = path
        self.lastPlayed = lastPlayed
        self.gameMode = gameMode
        self.difficulty = difficulty
        self.hardcore = hardcore
        self.cheats = cheats
        self.version = version
        self.seed = seed
    }
}

// MARK: - 截图信息模型
struct ScreenshotInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let path: URL
    let createdDate: Date?
    let fileSize: Int64

    init(name: String, path: URL, createdDate: Date? = nil, fileSize: Int64 = 0) {
        self.id = path.lastPathComponent
        self.name = name
        self.path = path
        self.createdDate = createdDate
        self.fileSize = fileSize
    }
}

// MARK: - 日志信息模型
struct LogInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let path: URL
    let createdDate: Date?
    let fileSize: Int64
    let isCrashLog: Bool

    init(name: String, path: URL, createdDate: Date? = nil, fileSize: Int64 = 0, isCrashLog: Bool = false) {
        self.id = path.lastPathComponent
        self.name = name
        self.path = path
        self.createdDate = createdDate
        self.fileSize = fileSize
        self.isCrashLog = isCrashLog
    }
}
