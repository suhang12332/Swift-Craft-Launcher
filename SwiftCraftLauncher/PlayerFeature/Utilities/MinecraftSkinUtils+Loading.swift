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
            return try await loadAssetData()
        case .url:
            return try await loadURLData()
        case .local:
            return try await loadLocalData()
        }
    }

    /// Loads skin data from the app's asset catalog.
    private func loadAssetData() async throws -> Data {
        guard let image = NSImage(named: src),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw GlobalError.resource(
                i18nKey: "error.resource.asset_not_found",
                level: .silent,
            )
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmapRep.representation(using: .png, properties: [:]) else {
            throw GlobalError.validation(
                i18nKey: "error.validation.invalid_image_data",
                level: .silent,
            )
        }

        return data
    }

    /// Loads skin data from a remote URL.
    private func loadURLData() async throws -> Data {
        guard let url = URL(string: src) else {
            throw GlobalError.validation(
                i18nKey: "error.validation.invalid_url",
                level: .silent,
            )
        }

        do {
            return try await APIClient.get(url: url)
        } catch let error as GlobalError where error.kind == .network {
            switch error.statusCode {
            case 404:
                throw GlobalError.resource(
                    i18nKey: "error.resource.skin_not_found",
                    level: .silent,
                )
            case 408, 504:
                throw GlobalError.download(
                    i18nKey: "error.download.network_timeout",
                    level: .silent,
                )
            default:
                throw GlobalError.download(
                    i18nKey: "error.download.skin_download_failed",
                    level: .silent,
                )
            }
        }
    }

    /// Loads skin data from a local file path.
    private func loadLocalData() async throws -> Data {
        let fileURL = URL(fileURLWithPath: src)
        return try Data(contentsOf: fileURL)
    }
}
