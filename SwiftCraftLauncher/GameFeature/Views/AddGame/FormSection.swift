//
//  FormSection.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// A reusable form section container with standard vertical padding.
import SwiftUI

struct FormSection<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .padding(.top, 6)
                .padding(.bottom, 6)
        }
    }
}
