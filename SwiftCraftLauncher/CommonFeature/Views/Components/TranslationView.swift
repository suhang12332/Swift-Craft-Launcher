//
//  TranslationView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI
@preconcurrency import Translation

/// Renders `text` through `content`, translating it in real time while translate
/// mode is active.
///
/// Observes `TranslationManager.isTranslateMode`; toggling translate mode on/off
/// re-translates the text on demand. When translate mode is off, or the
/// Translation framework is unavailable (macOS 14), the original text is passed
/// through unchanged.
struct TranslationView<Content: View>: View {
    let text: String
    let translationManager: TranslationManager
    @ViewBuilder let content: (String) -> Content

    init(
        text: String,
        translationManager: TranslationManager,
        @ViewBuilder content: @escaping (String) -> Content,
    ) {
        self.text = text
        self.translationManager = translationManager
        self.content = content
    }

    var body: some View {
        if #available(macOS 15, *) {
            TranslationView15(text: text, translationManager: translationManager, content: content)
        } else {
            content(text)
        }
    }
}

@available(macOS 15, *)
private struct TranslationView15<Content: View>: View {
    let text: String
    let translationManager: TranslationManager
    let content: (String) -> Content

    @Environment(\.locale)
    private var locale
    @State private var displayedText: String
    @State private var configuration: TranslationSession.Configuration?

    init(
        text: String,
        translationManager: TranslationManager,
        content: @escaping (String) -> Content,
    ) {
        self.text = text
        self.translationManager = translationManager
        self.content = content
        _displayedText = State(initialValue: text)
    }

    var body: some View {
        content(displayedText)
            .onAppear {
                updateConfiguration()
            }
            .onChange(of: text) { _, newText in
                displayedText = newText
                updateConfiguration()
            }
            .onChange(of: translationManager.isTranslateMode) { _, _ in
                updateConfiguration()
            }
            .translationTask(configuration) { session in
                guard translationManager.isTranslateMode else { return }
                if let response = try? await session.translate(text) {
                    displayedText = response.targetText
                } else {
                    displayedText = text
                }
            }
    }

    private func updateConfiguration() {
        if translationManager.isTranslateMode {
            if configuration == nil {
                configuration = TranslationSession.Configuration(source: Locale(identifier: "en").language, target: locale.language)
            } else {
                configuration?.invalidate()
            }
        } else {
            configuration = nil
            displayedText = text
        }
    }
}
