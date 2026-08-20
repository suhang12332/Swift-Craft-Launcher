//
//  TranslationManager.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Shared, transient state for real-time translation of resource content.
///
/// Toggled from the toolbar; observed by translation-aware views across windows,
/// sheets, and detail panes. The flag is intentionally not persisted.
@MainActor
@Observable
final class TranslationManager {
    var isTranslateMode = false

    init() { }
}
