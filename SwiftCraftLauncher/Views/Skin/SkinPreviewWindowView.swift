//
//  SkinPreviewWindowView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/27.
//

import Foundation
import SwiftUI
import AppKit
import SkinRenderKit

/// 皮肤预览窗口视图
struct SkinPreviewWindowView: View {
    let skinImage: NSImage?
    let skinPath: String?
    let capeImage: NSImage?
    let playerModel: PlayerModel

    @State private var capeBinding: NSImage?
    // 使用 @State 管理数据，以便在窗口关闭时清理
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
        // 初始化时设置当前值
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
        .frame(width: 1200, height: 800)
        .windowReferenceTracking {
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

    /// 清理所有数据
    private func clearAllData() {
        // 清空皮肤数据，这会导致 SkinRenderView 被移除，从而触发其清理逻辑
        currentSkinImage = nil
        currentSkinPath = nil
        capeBinding = nil
    }
}
