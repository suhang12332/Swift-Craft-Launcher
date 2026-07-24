//
//  DescriptionTextWithPopover.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays truncated text that reveals the full content in a popover on hover.
struct DescriptionTextWithPopover: View {
    let description: String
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .hoverPopover(isPresented: $showPopover, arrowEdge: .top) {
            VStack(alignment: .leading) {
                Text(description)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}
