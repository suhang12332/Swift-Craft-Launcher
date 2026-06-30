//
//  CapeSelectionViewModel.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import AppKit
import SwiftUI

/// Manages cape image loading and selection state.
@MainActor
final class CapeSelectionViewModel: ObservableObject {
    private let selectedCapeImageURL: Binding<String?>
    private let selectedCapeImage: Binding<NSImage?>

    private var loadTask: Task<Void, Never>?

    init(
        selectedCapeImageURL: Binding<String?>,
        selectedCapeImage: Binding<NSImage?>
    ) {
        self.selectedCapeImageURL = selectedCapeImageURL
        self.selectedCapeImage = selectedCapeImage
    }

    /// Loads the cape image from the specified URL if not already cached.
    ///
    /// - Parameter imageURL: The URL of the cape image.
    func loadCapeImageIfNeeded(imageURL: String?) {
        guard let imageURL else { return }

        loadTask?.cancel()
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let https = imageURL.httpToHttps()
            guard let url = URL(string: https) else { return }

            do {
                let data = try await DownloadManager.downloadData(from: url)
                guard !Task.isCancelled else { return }
                self.selectedCapeImageURL.wrappedValue = imageURL
                self.selectedCapeImage.wrappedValue = NSImage(data: data)
            } catch {
                return
            }
        }
    }

    /// Cancels any pending image loading operation.
    func cancel() {
        loadTask?.cancel()
        loadTask = nil
    }
}
