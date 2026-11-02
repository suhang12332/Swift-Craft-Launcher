//
//  GameNameTitleText.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Renders a localized title with the inserted game name in the secondary color.
struct GameNameTitleText: View {
    let formatKey: String
    let gameName: String

    var body: some View {
        let parts = formatKey.localized().components(separatedBy: "%@")
        Text(parts[0])
            + Text(gameName).foregroundColor(.secondary)
            + Text(parts[1])
    }
}
