//
//  LocalResourceUpdateButton.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

/// A button for updating an installed local resource.
import SwiftUI

struct LocalResourceUpdateButton: View {
    /// Whether the update button is visible.
    let isVisible: Bool
    /// Whether the update operation is in progress.
    @Binding var isUpdateButtonLoading: Bool
    /// The current state of the primary action button.
    let addButtonState: ModrinthDetailCardView.AddButtonState
    /// Called when the update button is tapped.
    let onTap: () -> Void

    var body: some View {
        Group {
            if isVisible {
                Button(action: onTap) {
                    if isUpdateButtonLoading {
                        ProgressView()
                            .controlSize(.mini)
                            .scaleEffect(1.3)
                    } else {
                        Text("resource.update".localized())
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .font(.caption2)
                .controlSize(.small)
                .disabled(addButtonState == .loading || isUpdateButtonLoading)
            }
        }
    }
}
