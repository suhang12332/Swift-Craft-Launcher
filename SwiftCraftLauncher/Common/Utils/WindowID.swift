//
//  WindowID.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/27.
//

import SwiftUI

/// 窗口标识符枚举
enum WindowID: String {
    case contributors = "contributors"
    case acknowledgements = "acknowledgements"
    case aiChat = "aiChat"
    case createRoom = "createRoom"
    case joinRoom = "joinRoom"
    case peerList = "peerList"
    case javaDownload = "javaDownload"
    case easyTierDownload = "easyTierDownload"
    case skinPreview = "skinPreview"
}

extension WindowID: CaseIterable {}
