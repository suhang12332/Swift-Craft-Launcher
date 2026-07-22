//
//  MinecraftSkinUtils+Loading.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import Foundation

extension MinecraftSkinUtils {
    /// Loads skin data from the appropriate source based on the skin type.
    func loadData() async throws -> Data {
        switch type {
        case .asset:
            if let match = URLConfig.API.DefaultAvatars.allCases.first(where: { $0.rawValue == src }) {
                return try await APIClient.get(url: match.url)
            }
            throw GlobalError.resource(
                i18nKey: "error.resource.asset_not_found",
                level: .silent,
                message: "Default avatar not found for name: \"\(src)\"",
            )
        case .url:
            guard let url = URL(string: src) else {
                throw GlobalError.validation(
                    i18nKey: "error.validation.invalid_url",
                    level: .silent,
                    message: "Invalid URL string: \"\(src)\"",
                )
            }
            return try await APIClient.get(url: url)
        case .local:
            let fileURL = URL(fileURLWithPath: src)
            return try Data(contentsOf: fileURL)
        }
    }
}
