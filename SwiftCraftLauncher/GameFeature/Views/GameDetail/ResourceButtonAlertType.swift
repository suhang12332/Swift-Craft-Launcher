//
//  ResourceButtonAlertType.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// Alert types presented by resource action buttons.
import SwiftUI

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

    /// The alert associated with this case.
    var alert: Alert {
        switch self {
        case .noGame:
            return Alert(
                title: Text("no_local_game.title".localized()),
                message: Text("no_local_game.message".localized()),
                dismissButton: .default(Text("common.confirm".localized())),
            )
        case .noPlayer:
            return Alert(
                title: Text("sidebar.alert.no_player.title".localized()),
                message: Text("sidebar.alert.no_player.message".localized()),
                dismissButton: .default(Text("common.confirm".localized())),
            )
        case .noPlayerForLaunch:
            return Alert(
                title: Text("sidebar.alert.no_player.title".localized()),
                message: Text("sidebar.alert.no_player_for_launch.message".localized()),
                dismissButton: .default(Text("common.confirm".localized())),
            )
        }
    }
}
