//
//  FabricLoaderModels.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A response from the Fabric Loader API.
struct FabricLoader: Codable {
    let loader: LoaderInfo

    struct LoaderInfo: Codable {
        let version: String
    }
}
