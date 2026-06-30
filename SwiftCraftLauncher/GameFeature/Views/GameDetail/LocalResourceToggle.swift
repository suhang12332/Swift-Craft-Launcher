//
//  LocalResourceToggle.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

/// A toggle switch for enabling or disabling a local resource.
import SwiftUI

struct LocalResourceToggle: View {
    /// Whether the toggle is visible.
    let isVisible: Bool
    /// Whether the resource is currently disabled.
    @Binding var isDisabled: Bool
    /// Called when the toggle value changes.
    let onToggle: () -> Void

    var body: some View {
        Group {
            if isVisible {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { !isDisabled },
                        set: { _ in onToggle() }
                    )
                )
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)
            }
        }
    }
}
