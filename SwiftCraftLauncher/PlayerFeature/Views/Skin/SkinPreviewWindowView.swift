//
//  SkinPreviewWindowView.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import Foundation
import SkinRenderKit
import SwiftUI

/// Data model for skin preview rendering.
struct SkinPreviewData {
    let skinImage: NSImage?
    let skinPath: String?
    let capeImage: NSImage?
    let playerModel: PlayerModel
}

/// A window that displays a 3D preview of the selected Minecraft skin and cape.
struct SkinPreviewWindowView: View {
    let data: SkinPreviewData

    @State private var capeBinding: NSImage?
    @State private var currentSkinImage: NSImage?
    @State private var currentSkinPath: String?

    init(data: SkinPreviewData) {
        self.data = data
        _capeBinding = State(initialValue: data.capeImage)
        _currentSkinImage = State(initialValue: data.skinImage)
        _currentSkinPath = State(initialValue: data.skinPath)
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
                playerModel: data.playerModel,
                rotationDuration: 0,
                backgroundColor: NSColor.clear,
                onSkinDropped: { _ in },
                onCapeDropped: { _ in },
            )
        }
    }

    private func clearAllData() {
        currentSkinImage = nil
        currentSkinPath = nil
        capeBinding = nil
    }
}
