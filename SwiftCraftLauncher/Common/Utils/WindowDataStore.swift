//
//  WindowDataStore.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/27.
//

import SwiftUI
import AppKit
import SkinRenderKit

/// 皮肤预览数据
struct SkinPreviewData {
    let skinImage: NSImage?
    let skinPath: String?
    let capeImage: NSImage?
    let playerModel: PlayerModel
}

/// 窗口数据存储，用于在窗口间传递数据
@MainActor
class WindowDataStore: ObservableObject {
    static let shared = WindowDataStore()

    private init() {}

    // AI Chat 窗口数据
    var aiChatState: ChatState?

    // Skin Preview 窗口数据
    var skinPreviewData: SkinPreviewData?

    /// 清理指定窗口的数据
    func cleanup(for windowID: WindowID) {
        switch windowID {
        case .aiChat:
            // 清理 AI Chat 数据
            if let chatState = aiChatState {
                chatState.clear()
            }
            aiChatState = nil
        case .skinPreview:
            // 清理 Skin Preview 数据
            skinPreviewData = nil
        default:
            // 其他窗口不需要清理 WindowDataStore
            break
        }
    }
}
