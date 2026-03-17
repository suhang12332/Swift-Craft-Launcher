import Foundation
import AppKit
import SwiftUI

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

    func loadCapeImageIfNeeded(imageURL: String?) {
        guard let imageURL else { return }

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }

            let https = imageURL.httpToHttps()
            guard let url = URL(string: https) else { return }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                self.selectedCapeImageURL.wrappedValue = imageURL
                self.selectedCapeImage.wrappedValue = NSImage(data: data)
            }
        }
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
    }
}
