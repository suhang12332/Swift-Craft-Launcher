//
//  GameOverviewItem.swift
//  GameFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A single resource summary row displayed in the game overview.
struct GameOverviewItem: Identifiable, Equatable, Sendable {
    static let errorSystemImage = "exclamationmark.triangle.fill"
    static let fallbackSystemImage = "shippingbox"

    enum Kind: String, Equatable, Sendable {
        case mod
        case datapack
        case resourcepack
        case shader
        case litematica
        case world
        case screenshot
        case log
        case server
    }

    let kind: Kind
    let itemCount: Int
    let directories: [URL]
    let hasError: Bool

    init(
        kind: Kind,
        itemCount: Int,
        directories: [URL] = [],
        hasError: Bool = false,
    ) {
        self.kind = kind
        self.itemCount = itemCount
        self.directories = directories
        self.hasError = hasError
    }

    var id: String { kind.rawValue }

    /// The localized display name for this overview type.
    var title: String {
        kind.title
    }

    /// The SF Symbol used by this overview type.
    var systemImage: String {
        kind.systemImage
    }
}

extension GameOverviewItem.Kind {
    /// The resource type backing this overview kind, when it has one.
    var resourceType: ResourceType? {
        switch self {
        case .mod:
            return .mod
        case .datapack:
            return .datapack
        case .resourcepack:
            return .resourcepack
        case .shader:
            return .shader
        case .server:
            return .minecraftJavaServer
        case .litematica, .world, .screenshot, .log:
            return nil
        }
    }

    /// Localization key shared by the overview chip and the matching section header.
    var titleKey: String {
        if let resourceType {
            return "resource.content.type.\(resourceType.rawValue)"
        }
        switch self {
        case .litematica:
            return "saveinfo.litematica"
        case .world:
            return "saveinfo.worlds"
        case .screenshot:
            return "saveinfo.screenshots"
        case .log:
            return "saveinfo.logs"
        case .mod, .datapack, .resourcepack, .shader, .server:
            return rawValue
        }
    }

    /// Localized display name for this overview type.
    var title: String {
        titleKey.localized()
    }

    /// The SF Symbol used by this overview type.
    var systemImage: String {
        if let resourceType {
            return resourceType.systemImage
        }
        switch self {
        case .litematica:
            return "square.stack.3d.up"
        case .world:
            return "folder.fill"
        case .screenshot:
            return "photo.fill"
        case .log:
            return "doc.text.fill"
        case .mod, .datapack, .resourcepack, .shader, .server:
            return GameOverviewItem.fallbackSystemImage
        }
    }
}
