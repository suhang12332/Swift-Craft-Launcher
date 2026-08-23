//
//  ResourceCountSectionView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// Displays the installed resource counts for a game as a section.
import SwiftUI

struct ResourceCountSectionView: View {
    let counts: [(type: String, count: Int, directory: URL?)]

    var body: some View {
        GenericSectionView(
            title: "game.info.overview",
            items: counts.map { ResourceCountItem(type: $0.type, count: $0.count, directory: $0.directory) },
            isLoading: false,
            maxItems: counts.count,
            iconName: "shippingbox",
        ) { item in
            FilterChip(
                title: "\(label(for: item.type)) \(item.count)",
                action: {
                    if let url = item.directory {
                        NSWorkspace.shared.open(url)
                    }
                },
                iconName: icon(for: item.type),
            )
        }
    }

    private func label(for type: String) -> String {
        switch type {
        case ResourceType.mod.rawValue:
            return "resource.content.type.mod".localized()
        case ResourceType.datapack.rawValue:
            return "resource.content.type.datapack".localized()
        case ResourceType.resourcepack.rawValue:
            return "resource.content.type.resourcepack".localized()
        case ResourceType.shader.rawValue:
            return "resource.content.type.shader".localized()
        case "litematica":
            return "saveinfo.litematica".localized()
        case "worlds":
            return "saveinfo.worlds".localized()
        case "screenshots":
            return "saveinfo.screenshots".localized()
        case "logs":
            return "saveinfo.logs".localized()
        case "servers":
            return "resource.content.type.minecraft_java_server".localized()
        default:
            return type
        }
    }

    private func icon(for type: String) -> String {
        switch type {
        case ResourceType.mod.rawValue:
            return ResourceType.mod.systemImage
        case ResourceType.datapack.rawValue:
            return ResourceType.datapack.systemImage
        case ResourceType.resourcepack.rawValue:
            return ResourceType.resourcepack.systemImage
        case ResourceType.shader.rawValue:
            return ResourceType.shader.systemImage
        case "litematica":
            return "square.stack.3d.up"
        case "worlds":
            return "folder.fill"
        case "screenshots":
            return "photo.fill"
        case "logs":
            return "doc.text.fill"
        case "servers":
            return ResourceType.minecraftJavaServer.systemImage
        default:
            return "shippingbox"
        }
    }
}

/// An identifiable resource count item.
struct ResourceCountItem: Identifiable {
    let type: String
    let count: Int
    let directory: URL?

    var id: String { type }
}
