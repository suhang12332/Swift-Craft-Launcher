//
//  CacheInfoManager.swift
//  CommonFeature
//
//  Computes cache size information for data and game profiles.
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Manages cache size calculations for application data and game profiles.
class CacheInfoManager: ObservableObject {
    static let shared = CacheInfoManager()

    @Published var cacheInfo: CacheInfo = CacheInfo(fileCount: 0, totalSize: 0)
    private let errorHandler: GlobalErrorHandler
    private let calculator: CacheCalculator

    init(
        errorHandler: GlobalErrorHandler = AppServices.errorHandler,
        calculator: CacheCalculator = AppServices.cacheCalculator
    ) {
        self.errorHandler = errorHandler
        self.calculator = calculator
    }

    /// Calculates cache size for application data.
    func calculateDataCacheInfo() {
        do {
            self.cacheInfo = try calculator.calculateCacheInfo()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("计算数据缓存信息失败: \(globalError.chineseMessage)")
            errorHandler.handle(globalError)
        }
    }

    /// Calculates cache size for a specific game's profile data.
    /// - Parameter game: The game name to calculate cache for.
    func calculateGameCacheInfo(_ game: String) {
        do {
            self.cacheInfo = try calculator.calculateProfileCacheInfo(gameName: game)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("计算游戏缓存信息失败: \(globalError.chineseMessage)")
            errorHandler.handle(globalError)
        }
    }
}
