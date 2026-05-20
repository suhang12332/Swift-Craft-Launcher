//
//  ThemeManager.swift
//  SwiftCraftLauncher
//
//

import AppKit
import Combine
import Foundation
import SwiftUI

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage(AppConstants.UserDefaultsKeys.themeMode)
    var themeMode: ThemeMode = .system {
        didSet {
            applyAppAppearance()
            objectWillChange.send()
        }
    }

    private var appearanceObserver: NSKeyValueObservation?

    private init() {
        DispatchQueue.main.async { [weak self] in
            self?.applyAppAppearance()
            self?.setupAppearanceObserver()
        }
    }

    deinit {
        appearanceObserver?.invalidate()
    }

    var currentColorScheme: ColorScheme? {
        guard NSApplication.shared.isRunning else {
            return themeMode == .system ? nil : themeMode.effectiveColorScheme
        }
        return themeMode.effectiveColorScheme
    }

    private func setupAppearanceObserver() {
        appearanceObserver = NSApp.observe(
            \.effectiveAppearance,
            options: [.new, .initial]
        ) { [weak self] _, _ in
            guard let self, self.themeMode == .system else { return }
            self.objectWillChange.send()
        }
    }

    func applyAppAppearance() {
        let appearance = themeMode.nsAppearance
        if Thread.isMainThread {
            NSApp.appearance = appearance
        } else {
            DispatchQueue.main.async {
                NSApp.appearance = appearance
            }
        }
    }
}
