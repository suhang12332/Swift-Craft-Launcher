//
//  OnboardingManager.swift
//  SwiftCraftLauncher
//
//  Created by Auto on 2025/1/28.
//

import Foundation

/// Onboarding 管理器
/// 用于管理首次启动引导的显示状态
class OnboardingManager {
    static let shared = OnboardingManager()
    
    private let hasShownOnboardingKey = "hasShownOnboarding"
    
    private init() {}
    
    /// 检查是否已经显示过引导
    var hasShownOnboarding: Bool {
        get {
            UserDefaults.standard.bool(forKey: hasShownOnboardingKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hasShownOnboardingKey)
        }
    }
    
    /// 标记已显示引导
    func markOnboardingAsShown() {
        hasShownOnboarding = true
    }
    
    /// 重置引导状态（用于测试）
    func resetOnboarding() {
        hasShownOnboarding = false
    }
}

