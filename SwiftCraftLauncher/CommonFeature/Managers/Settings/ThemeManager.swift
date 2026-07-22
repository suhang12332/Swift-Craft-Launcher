//
//  ThemeManager.swift
//  CommonFeature
//
//  Manages app appearance themes including light, dark, and system modes.
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI

/// The available theme modes for the application.
public enum ThemeMode: String, CaseIterable {
    case light
    case dark
    case system

    public var localizedName: String {
        "settings.theme.\(rawValue)".localized()
    }

    public var preferredColorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: Self.resolveSystemColorScheme()
        }
    }

    public var nsAppearance: NSAppearance? {
        switch self {
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        case .system: nil
        }
    }

    static func resolveSystemColorScheme() -> ColorScheme {
        let appearance = NSApp?.effectiveAppearance ?? NSApplication.shared.effectiveAppearance
        let bestMatch = appearance.bestMatch(from: [.aqua, .darkAqua])
        return bestMatch == .darkAqua ? .dark : .light
    }
}

/// Manages the app's visual theme and applies the selected appearance.
@Observable
final class ThemeManager {
    var themeMode: ThemeMode = Defaults.loadEnum(forKey: AppConstants.UserDefaultsKeys.themeMode, defaultValue: .system) {
        didSet {
            Defaults.save(themeMode.rawValue, forKey: AppConstants.UserDefaultsKeys.themeMode)
            applyAppAppearance()
        }
    }

    /// Increments when the system appearance changes while in system mode,
    /// so that SwiftUI views observing this property re-evaluate.
    private var systemAppearanceRevision = 0

    var preferredColorScheme: ColorScheme? {
        _ = systemAppearanceRevision
        return themeMode.preferredColorScheme
    }

    private var appearanceObserver: NSKeyValueObservation?

    init() {
        applyAppAppearance()
        setupAppearanceObserverIfNeeded()
    }

    deinit {
        appearanceObserver?.invalidate()
    }

    func applyAppAppearance() {
        NSApp?.appearance = themeMode.nsAppearance
    }

    private func setupAppearanceObserverIfNeeded() {
        appearanceObserver?.invalidate()
        guard let app = NSApp else { return }
        appearanceObserver = app.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                guard let self, self.themeMode == .system else { return }
                self.systemAppearanceRevision += 1
            }
        }
    }
}
