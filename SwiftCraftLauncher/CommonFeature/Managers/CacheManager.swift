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

    /// 计算数据缓存信息（静默版本）
    func calculateDataCacheInfo() {
        do {
            self.cacheInfo = try calculator.calculateCacheInfo()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("计算数据缓存信息失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
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
        }
    }
}
