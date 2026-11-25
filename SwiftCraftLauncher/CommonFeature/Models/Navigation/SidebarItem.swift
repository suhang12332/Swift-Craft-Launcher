//
//  SidebarItem.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// An item displayed in the sidebar navigation.
public enum SidebarItem: Hashable, Identifiable {
    case game(String)
    case resource(ResourceType)

    /// The unique identifier for this sidebar item.
    public var id: String {
        switch self {
        case let .game(gameId):
            return "game_\(gameId)"
        case let .resource(type):
            return "resource_\(type.rawValue)"
        }
    }

    /// The display title for this sidebar item.
    public var title: String {
        switch self {
        case let .game(gameId):
            return gameId
        case let .resource(type):
            return type.localizedName
        }
    }
}
