import Foundation

/// 游戏版本数据迁移脚本
/// 负责将 UserDefaults 中的游戏版本数据迁移到 SQLite 数据库
class GameVersionMigration {
    // MARK: - Constants

    private let gamesKey = AppConstants.UserDefaultsKeys.savedGames
    private let migrationKey = "gameVersionDatabaseMigrated"

    // MARK: - Properties

    private let database: GameVersionDatabase

    // MARK: - Initialization

    /// 初始化迁移脚本
    /// - Parameter database: 游戏版本数据库实例
    init(database: GameVersionDatabase) {
        self.database = database
    }

    // MARK: - Migration

    /// 检查是否需要迁移
    /// - Returns: 如果需要迁移则返回 true，否则返回 false
    func needsMigration() -> Bool {
        // 如果已经迁移过，则不需要再次迁移
        if UserDefaults.standard.bool(forKey: migrationKey) {
            return false
        }

        // 检查 UserDefaults 中是否有数据
        guard let savedGamesData = UserDefaults.standard.data(forKey: gamesKey) else {
            return false
        }

        // 检查数据是否有效
        guard (try? JSONDecoder().decode([String: [GameVersionInfo]].self, from: savedGamesData)) != nil else {
            return false
        }

        return true
    }

    /// 执行数据迁移
    /// - Throws: GlobalError 当迁移失败时
    func migrate() throws {
        guard needsMigration() else {
            Logger.shared.debug("无需迁移游戏版本数据")
            return
        }

        Logger.shared.info("开始迁移游戏版本数据从 UserDefaults 到 SQLite...")

        guard let savedGamesData = UserDefaults.standard.data(forKey: gamesKey) else {
            Logger.shared.debug("没有需要迁移的游戏数据")
            markAsMigrated()
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            let allGamesByPath = try decoder.decode([String: [GameVersionInfo]].self, from: savedGamesData)

            var totalGames = 0
            // 迁移所有工作路径的游戏
            for (workingPath, games) in allGamesByPath {
                try database.saveGames(games, workingPath: workingPath)
                totalGames += games.count
                Logger.shared.debug("已迁移 \(games.count) 个游戏（工作路径: \(workingPath)）")
            }

            // 标记为已迁移
            markAsMigrated()

            Logger.shared.info("成功迁移 \(totalGames) 个游戏到 SQLite 数据库")
        } catch {
            Logger.shared.error("迁移游戏版本数据失败: \(error.localizedDescription)")
            throw GlobalError.validation(
                chineseMessage: "迁移游戏版本数据失败: \(error.localizedDescription)",
                i18nKey: "error.validation.migration_failed",
                level: .notification
            )
        }
    }

    /// 标记为已迁移
    private func markAsMigrated() {
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    /// 重置迁移状态（用于测试或重新迁移）
    /// - Warning: 仅用于测试或调试
    func resetMigrationStatus() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
        Logger.shared.debug("已重置迁移状态")
    }

    /// 获取迁移统计信息
    /// - Returns: 迁移统计信息，包含需要迁移的游戏数量
    func getMigrationStats() -> (needsMigration: Bool, gameCount: Int) {
        guard needsMigration() else {
            return (needsMigration: false, gameCount: 0)
        }

        guard let savedGamesData = UserDefaults.standard.data(forKey: gamesKey),
              let allGamesByPath = try? JSONDecoder().decode([String: [GameVersionInfo]].self, from: savedGamesData) else {
            return (needsMigration: false, gameCount: 0)
        }

        let totalGames = allGamesByPath.values.reduce(0) { $0 + $1.count }
        return (needsMigration: true, gameCount: totalGames)
    }
}
