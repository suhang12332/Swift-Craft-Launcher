//
//  ScreenshotImageViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import AppKit

/// View model that loads a screenshot thumbnail asynchronously from a file URL.
@MainActor
final class ScreenshotThumbnailViewModel: ObservableObject {
    @Published var image: NSImage?

    func load(path: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let nsImage = NSImage(contentsOf: path) {
                DispatchQueue.main.async {
                    self.image = nsImage
                }
            }
        }
    }

    func reset() {
        image = nil
    }
}

/// View model that loads a full-size screenshot image asynchronously, tracking loading and failure states.
@MainActor
final class ScreenshotImageViewModel: ObservableObject {
    @Published var image: NSImage?
    @Published var isLoading: Bool = true
    @Published var loadFailed: Bool = false

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
