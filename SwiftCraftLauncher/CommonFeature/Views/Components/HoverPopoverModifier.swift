//
//  HoverPopoverModifier.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Attaches a hover-triggered popover with self-managed state.
struct HoverPopoverModifier<PopoverContent: View>: ViewModifier {
    let delay: Double
    let arrowEdge: Edge
    @ViewBuilder let popoverContent: () -> PopoverContent

    @State private var isPresented = false
    @State private var hoverTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if hovering {
                    hoverTask?.cancel()
                    hoverTask = Task {
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        guard !Task.isCancelled else { return }
                        await MainActor.run { isPresented = true }
                    }
                } else {
                    hoverTask?.cancel()
                    isPresented = false
                }
            }
            .popover(isPresented: $isPresented, arrowEdge: arrowEdge) {
                popoverContent()
                    .font(.subheadline)
                    .padding()
            }
            .onDisappear {
                hoverTask?.cancel()
                isPresented = false
            }
    }
}

extension View {
    func hoverPopover(
        delay: Double = 0.5,
        arrowEdge: Edge = .top,
        @ViewBuilder content: @escaping () -> some View,
    ) -> some View {
        modifier(HoverPopoverModifier(delay: delay, arrowEdge: arrowEdge, popoverContent: content))
    }
}
