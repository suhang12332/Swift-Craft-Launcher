//
//  UpdateSource.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Describes a complete Sparkle update source.
///
/// The appcast and download endpoints stay paired so an update discovered from one source is
/// downloaded from the matching mirror.
struct UpdateSource: Equatable, Sendable {
    let id: String
    let name: String
    let appcastBaseURL: URL
    let downloadBaseURL: URL

    func appcastURL(architecture: String) -> URL {
        appcastBaseURL.appendingPathComponent("appcast-\(architecture).xml")
    }

    func downloadURL(version: String, fileName: String) -> URL {
        downloadBaseURL
            .appendingPathComponent(version)
            .appendingPathComponent(fileName)
    }
}
