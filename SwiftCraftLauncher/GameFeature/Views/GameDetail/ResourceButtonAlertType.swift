//
//  ResourceButtonAlertType.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/28.
//

import SwiftUI

/// 资源按钮的 Alert 类型枚举
enum ResourceButtonAlertType: Identifiable {
    case noGame
    case noPlayer
    case noPlayerForLaunch

    var id: String {
        switch self {
        case .noGame: return "noGame"
        case .noPlayer: return "noPlayer"
        case .noPlayerForLaunch: return "noPlayerForLaunch"
        }
    }

    /// 创建对应的 Alert
    var alert: Alert {
        switch self {
        case .noGame:
            return Alert(
                title: Text("no_local_game.title".localized()),
                message: Text("no_local_game.message".localized()),
                dismissButton: .default(Text("common.confirm".localized()))
            )
        case .noPlayer:
            return Alert(
                title: Text("sidebar.alert.no_player.title".localized()),
                message: Text("sidebar.alert.no_player.message".localized()),
                dismissButton: .default(Text("common.confirm".localized()))
            )
        case .noPlayerForLaunch:
            return Alert(
                title: Text("sidebar.alert.no_player.title".localized()),
                message: Text("sidebar.alert.no_player_for_launch.message".localized()),
                dismissButton: .default(Text("common.confirm".localized()))
            )
        }
    }
}
