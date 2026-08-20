//
//  TranslationToolbarButton.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A toolbar button that toggles real-time translation of resource content.
///
/// While translate mode is on, visible list items and the detail view translate
/// their content to the system language on demand.
struct TranslationToolbarButton: View {
    @Environment(TranslationManager.self)
    private var translationManager

    var body: some View {
        Button {
            translationManager.isTranslateMode.toggle()
        } label: {
            Label(
                "translate".localized(),
                systemImage: "translate",
            )
            .foregroundColor(translationManager.isTranslateMode ? .green : nil)
        }
        .help(
            translationManager.isTranslateMode
                ? "translate.clear.help".localized()
                : "translate.help".localized(),
        )
    }
}
