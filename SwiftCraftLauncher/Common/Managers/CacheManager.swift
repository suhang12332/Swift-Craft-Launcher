//
//  CacheManager.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/7/31.
//
import SwiftUI

class CacheManager: ObservableObject {
    @Published var cacheInfo: CacheInfo = CacheInfo(fileCount: 0, totalSize: 0)
    private let calculator = CacheCalculator.shared
    
    /// 计算元数据缓存信息（静默版本）
    func calculateMetaCacheInfo() {
        do {
            self.cacheInfo = try calculator.calculateMetaCacheInfo()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("计算元数据缓存信息失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            // 保持默认值
        }
    }
    
    /// 计算元数据缓存信息（抛出异常版本）
    /// - Throws: GlobalError 当操作失败时
    func calculateMetaCacheInfoThrowing() throws {
        do {
            self.cacheInfo = try calculator.calculateMetaCacheInfo()
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "计算元数据缓存信息失败: \(error.localizedDescription)",
                i18nKey: "error.filesystem.meta_cache_calculation_failed",
                level: .notification
            )
        }
    }
    
    /// 计算数据缓存信息（静默版本）
    func calculateDataCacheInfo() {
        do {
            self.cacheInfo = try calculator.calculateCacheInfo()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("计算数据缓存信息失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            // 保持默认值
        }
    }
    
    /// 计算数据缓存信息（抛出异常版本）
    /// - Throws: GlobalError 当操作失败时
    func calculateDataCacheInfoThrowing() throws {
        do {
            self.cacheInfo = try calculator.calculateCacheInfo()
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "计算数据缓存信息失败: \(error.localizedDescription)",
                i18nKey: "error.filesystem.data_cache_calculation_failed",
                level: .notification
            )
        }
    }
    
    /// 计算游戏缓存信息（静默版本）
    /// - Parameter game: 游戏名称
    func calculateGameCacheInfo(_ game: String) {
        do {
            self.cacheInfo = try calculator.calculateProfileCacheInfo(gameName: game)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("计算游戏缓存信息失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            // 保持默认值
        }
    }
    
    /// 计算游戏缓存信息（抛出异常版本）
    /// - Parameter game: 游戏名称
    /// - Throws: GlobalError 当操作失败时
    func calculateGameCacheInfoThrowing(_ game: String) throws {
        do {
            self.cacheInfo = try calculator.calculateProfileCacheInfo(gameName: game)
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "计算游戏缓存信息失败: \(error.localizedDescription)",
                i18nKey: "error.filesystem.game_cache_calculation_failed",
                level: .notification
            )
        }
    }
}
