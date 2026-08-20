//
//  TranslatedText.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays `text`, translating it in real time while translate mode is active.
struct TranslatedText: View {
    let text: String
    @Environment(TranslationManager.self)
    private var translationManager

    var body: some View {
        TranslationView(text: text, translationManager: translationManager) { displayed in
            Text(displayed)
        }
    }
}
