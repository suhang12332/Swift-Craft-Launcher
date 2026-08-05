//
//  ScreenshotImageViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import Foundation
import Observation

/// View model that loads a full-size screenshot image asynchronously, tracking loading and failure states.
@MainActor
@Observable
final class ScreenshotImageViewModel {
    var image: NSImage?
    var isLoading: Bool = true
    var loadFailed: Bool = false

    func load(path: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let nsImage = NSImage(contentsOf: path) {
                DispatchQueue.main.async {
                    self.image = nsImage
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.loadFailed = true
                    self.isLoading = false
                }
            }
        }
    }

    func reset() {
        image = nil
        isLoading = true
        loadFailed = false
    }
}
