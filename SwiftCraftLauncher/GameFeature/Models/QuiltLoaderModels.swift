//
//  QuiltLoaderModels.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A response from the Quilt Loader API.
struct QuiltLoaderResponse: Codable {
    struct Loader: Codable {
        let version: String
    }

    let loader: Loader
}
