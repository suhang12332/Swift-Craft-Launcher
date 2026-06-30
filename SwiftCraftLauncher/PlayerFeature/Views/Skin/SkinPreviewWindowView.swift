//
//  SkinPreviewWindowView.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI
import AppKit
import SkinRenderKit

/// A window that displays a 3D preview of the selected Minecraft skin and cape.
struct SkinPreviewWindowView: View {
    let skinImage: NSImage?
    let skinPath: String?
    let capeImage: NSImage?
    let playerModel: PlayerModel

    @State private var capeBinding: NSImage?
    @State private var currentSkinImage: NSImage?
    @State private var currentSkinPath: String?

    init(
        skinImage: NSImage?,
        skinPath: String?,
        capeImage: NSImage?,
        playerModel: PlayerModel
    ) {
        self.skinImage = skinImage
        self.skinPath = skinPath
        self.capeImage = capeImage
        self.playerModel = playerModel
        self._capeBinding = State(initialValue: capeImage)
        self._currentSkinImage = State(initialValue: skinImage)
        self._currentSkinPath = State(initialValue: skinPath)
    }

    var body: some View {
        VStack(spacing: 16) {
            if currentSkinImage != nil || currentSkinPath != nil {
                previewContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: AuxiliaryWindowID.skinPreview.defaultSize.width, height: AuxiliaryWindowID.skinPreview.defaultSize.height)
        .onDisappear {
            clearAllData()
        }
    }

    @ViewBuilder private var previewContent: some View {
        if let image = currentSkinImage {
            SkinRenderView(
                skinImage: image,
                capeImage: $capeBinding,
                playerModel: playerModel,
                rotationDuration: 0,
                backgroundColor: NSColor.clear,
                onSkinDropped: { _ in },
                onCapeDropped: { _ in }
            )
        }
    }

    private func clearAllData() {
        currentSkinImage = nil
        currentSkinPath = nil
        capeBinding = nil
    }
}
