//
//  LanguageManager.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Provides the effective app language without modifying it at runtime.
public class LanguageManager {

    public var selectedLanguage: String {
        Self.getDefaultLanguage()
    }

    public static let shared = LanguageManager()

    private init() {}

    /// Returns the language code currently in use by the app, respecting system preferences and supported localizations.
    public static func getDefaultLanguage() -> String {
        Bundle.main.preferredLocalizations.first ?? "en"
    }

    /// Returns the localized display name for a language code.
    /// - Parameters:
    ///   - code: The language or region identifier (e.g. "en", "zh-Hans", "ja").
    ///   - locale: The locale used for display name resolution.
    /// - Returns: A localized display name, falling back to English if unresolvable.
    public static func displayName(for code: String, locale: Locale = .current) -> String {
        let name = locale.localizedString(forIdentifier: code)
            ?? locale.localizedString(forIdentifier: "en")
            ?? "English"
        return name
    }

    /// The display name of the currently effective language.
    public var selectedLanguageDisplayName: String {
        Self.displayName(for: selectedLanguage)
    }
}

extension String {
    /// Returns the localized version of this string using the specified bundle.
    /// - Parameter bundle: The bundle to search for localized strings.
    /// - Returns: The localized string, or the key itself if no translation exists.
    public func localized(
        _ bundle: Bundle = .main
    ) -> String {
        bundle.localizedString(forKey: self, value: self, table: nil)
    }
}
