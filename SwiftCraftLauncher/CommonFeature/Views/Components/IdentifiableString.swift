//
//  IdentifiableString.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

/// A string wrapper that conforms to Identifiable.
public struct IdentifiableString: Identifiable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}
