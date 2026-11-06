//
//  ModDependencyExportView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI

/// Immutable graph rendering used when saving a high-resolution image.
struct ModDependencyExportView: View {
    let layout: ModDependencyGraphLayout
    let game: GameVersionInfo
    let gameIcon: NSImage?
    let projectIcons: [String: NSImage]
    private let frames: [String: CGRect]

    init(
        layout: ModDependencyGraphLayout,
        game: GameVersionInfo,
        gameIcon: NSImage?,
        projectIcons: [String: NSImage],
    ) {
        self.layout = layout
        self.game = game
        self.gameIcon = gameIcon
        self.projectIcons = projectIcons
        frames = layout.framesByNodeID
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                drawModDependencyConnections(
                    edges: layout.edges,
                    frames: frames,
                    in: &context,
                )
            }
            .frame(width: layout.size.width, height: layout.size.height)

            GameDependencyCard(
                game: game,
                icon: gameIcon,
            )
            .position(x: layout.rootFrame.midX, y: layout.rootFrame.midY)

            ForEach(layout.nodes) { node in
                ModDependencyCard(
                    node: node.mod,
                    icon: projectIcons[node.mod.projectId],
                )
                .position(x: node.frame.midX, y: node.frame.midY)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.colorScheme, .light)
    }
}
