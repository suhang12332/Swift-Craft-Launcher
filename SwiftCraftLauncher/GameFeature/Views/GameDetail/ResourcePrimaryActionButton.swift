//
//  ResourcePrimaryActionButton.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

/// A primary action button for installing or deleting resources.
import SwiftUI

struct ResourcePrimaryActionButton: View {
    let addButtonState: ModrinthDetailCardView.AddButtonState
    /// When true the resource targets a server; when false, local.
    let type: Bool
    /// Whether the button is disabled.
    let isDisabled: Bool
    /// Called when the button is tapped.
    let onTap: () -> Void

    let query: String

    var body: some View {
        Button(action: onTap) {
            label
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
        .font(.caption2)
        .controlSize(.small)
        .disabled(isDisabled)
    }

    @ViewBuilder private var label: some View {
        switch addButtonState {
        case .idle:
            Text((
                query == ResourceType.minecraftJavaServer.rawValue ? "addplayer.auth.add" : "resource.add"
            ).localized())
        case .loading:
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(1.3)
        case .installed:
            Text(
                (!type
                    ? "common.delete".localized()
                    : "resource.installed".localized())
            )
        case .update:
            Text("common.delete".localized())
        }
    }
}
