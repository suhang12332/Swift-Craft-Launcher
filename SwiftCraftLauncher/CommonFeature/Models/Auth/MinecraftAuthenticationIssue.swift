//
//  MinecraftAuthenticationIssue.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

enum MinecraftEntitlement: String, CaseIterable {
    case productMinecraft = "product_minecraft"
    case gameMinecraft = "game_minecraft"

    var displayName: String {
        switch self {
        case .productMinecraft:
            return "Minecraft Product License"
        case .gameMinecraft:
            return "Minecraft Game License"
        }
    }
}

enum MinecraftAuthenticationIssue: Equatable {
    case profileMissing
    case notPurchased

    var actionURL: URL {
        switch self {
        case .profileMissing:
            URLConfig.Store.minecraftProfileCreation
        case .notPurchased:
            URLConfig.Store.minecraftPurchase
        }
    }

    var errorInfo: String {
        switch self {
        case .profileMissing:
            "minecraft.auth.create_profile_message"
        case .notPurchased:
            "minecraft.auth.purchase_minecraft_message"
        }
    }

    var buttonInfo: String {
        switch self {
        case .profileMissing:
            "minecraft.auth.create_profile"
        case .notPurchased:
            "addplayer.purchase.minecraft"
        }
    }
}

/// The current state of the Microsoft authentication flow.
typealias AuthenticationState = AuthFlowState<MinecraftProfileResponse>
