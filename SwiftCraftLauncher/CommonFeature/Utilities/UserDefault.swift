//
//  UserDefault.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Helpers for reading and writing UserDefaults, reducing boilerplate in @Observable classes.
enum Defaults {
    static func save(_ value: some Any, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    static func loadBool(forKey key: String, defaultValue: Bool = false) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
    }

    static func loadInt(forKey key: String, defaultValue: Int = 0) -> Int {
        UserDefaults.standard.object(forKey: key) as? Int ?? defaultValue
    }

    static func loadString(forKey key: String, defaultValue: String = "") -> String {
        UserDefaults.standard.string(forKey: key) ?? defaultValue
    }

    static func loadEnum<T: RawRepresentable>(forKey key: String, defaultValue: T) -> T where T.RawValue == String {
        guard let raw = UserDefaults.standard.string(forKey: key) else { return defaultValue }
        return T(rawValue: raw) ?? defaultValue
    }
}
