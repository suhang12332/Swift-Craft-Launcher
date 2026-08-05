//
//  CustomLabeledContentStyle.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

struct CustomLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        LabeledContent {
            configuration.content
        } label: {
            HStack(spacing: 0) {
                configuration.label
                Text(":")
            }
        }
        .padding(.vertical, 2)
    }
}

struct CustomLabeledContentStyleNoColon: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        LabeledContent {
            configuration.content
        } label: {
            configuration.label
        }
        .padding(.vertical, 2)
    }
}

extension LabeledContentStyle where Self == CustomLabeledContentStyle {
    static var custom: Self { .init() }
}

extension LabeledContentStyle where Self == CustomLabeledContentStyleNoColon {
    static var customNoColon: Self { .init() }
}
