//
//  SidebarItem.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
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

/// The type of content resource available in the launcher.
public enum ResourceType: String, CaseIterable {
    case mod
    case datapack
    case shader
    case resourcepack
    case modpack
    case minecraftJavaServer = "minecraft_java_server"

    /// The localized name of this resource type.
    public var localizedName: String {
        "resource.content.type.\(rawValue)".localized()
    }

    /// The SF Symbol image name for this resource type.
    public var systemImage: String {
        switch self {
        case .mod:
            return "puzzlepiece.extension"
        case .datapack:
            return "doc.text"
        case .shader:
            return "sparkles"
        case .resourcepack:
            return "paintpalette"
        case .modpack:
            return "cube.box"
        case .minecraftJavaServer:
            return "server.rack"
        }
    }

    /// The folder name used in the game profile directory for this resource type.
    /// Returns an empty string for types without a physical directory (modpack, server).
    public var folderName: String {
        switch self {
        case .mod: return AppConstants.DirectoryNames.mods
        case .datapack: return AppConstants.DirectoryNames.datapacks
        case .shader: return AppConstants.DirectoryNames.shaderpacks
        case .resourcepack: return AppConstants.DirectoryNames.resourcepacks
        case .modpack, .minecraftJavaServer: return ""
        }
    }

    /// Creates a `ResourceType` from a case-insensitive string.
    public init?(from string: String) {
        self.init(rawValue: string.lowercased())
    }
}
