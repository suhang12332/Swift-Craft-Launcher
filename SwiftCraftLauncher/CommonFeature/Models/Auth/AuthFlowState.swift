//
//  AuthFlowState.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Generic authentication flow state, parameterized by the profile type.
enum AuthFlowState<Profile: Equatable>: Equatable {
    case idle
    case waitingForBrowser
    case processing
    case authenticated(profile: Profile)
    case error(String)
}
