//
//  ThemeManager.swift
//  SwiftCraftLauncher
//

import AppKit
import SwiftUI

public enum ThemeMode: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"

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

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage(AppConstants.UserDefaultsKeys.themeMode)
    var themeMode: ThemeMode = .system {
        didSet {
            applyAppAppearance()
            objectWillChange.send()
        }
    }

    var preferredColorScheme: ColorScheme? { themeMode.preferredColorScheme }

    private var appearanceObserver: NSKeyValueObservation?

    private init() {
        applyAppAppearance()
        Task { @MainActor in
            setupAppearanceObserverIfNeeded()
        }
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
                self.objectWillChange.send()
            }
        }
    }
}
