//
//  WindowDataStore.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SkinRenderKit
import SwiftUI

/// Data model for skin preview rendering.
struct SkinPreviewData {
    let skinImage: NSImage?
    let skinPath: String?
    let capeImage: NSImage?
    let playerModel: PlayerModel
}

/// Shared observable store for passing data between auxiliary windows.
@MainActor
class WindowDataStore: ObservableObject {
    init() { }

    @Published var aiChatState: ChatState?

    @Published var skinPreviewData: SkinPreviewData?

    /// Releases the data associated with the specified window.
    func cleanup(for windowID: AuxiliaryWindowID) {
        switch windowID {
        case .aiChat:
            if let chatState = aiChatState {
                chatState.clear()
            }
            aiChatState = nil
        case .skinPreview:
            skinPreviewData = nil
        default:
            break
        }
    }
}
