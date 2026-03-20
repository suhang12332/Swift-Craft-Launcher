import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension SkinToolDetailViewModel {
    // MARK: - 当前皮肤渲染图

    func loadCurrentSkinRenderImageIfNeeded(resolvedPlayer: Player?) {
        if selectedSkinImage != nil || selectedSkinPath != nil { return }
        guard let urlString = publicSkinInfo?.skinURL?.httpToHttps(),
              let url = URL(string: urlString) else { return }

        loadSkinImageTask?.cancel()
        loadSkinImageTask = Task {
            do {
                let p = self.playerWithCredentialIfNeeded(resolvedPlayer)
                var headers: [String: String]?
                if let t = p?.authAccessToken, !t.isEmpty {
                    headers = ["Authorization": "Bearer \(t)"]
                } else {
                    headers = nil
                }
                let data = try await APIClient.get(url: url, headers: headers)
                guard !data.isEmpty, let image = NSImage(data: data) else { return }
                try Task.checkCancellation()
                self.currentSkinRenderImage = image
            } catch is CancellationError {
            } catch {
                Logger.shared.error("Failed to load current skin image for renderer: \(error)")
            }
        }
    }

    // MARK: - File Import & Drop

    func handleSkinDroppedImage(_ image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:])
        else {
            Logger.shared.error("Failed to convert dropped image to PNG data")
            return
        }

        guard data.isPNG else {
            Logger.shared.error("Converted data is not valid PNG format")
            return
        }

        selectedSkinData = data
        selectedSkinImage = image
        Task {
            let path = await Task.detached(priority: .userInitiated) {
                self.saveTempSkinFile(data: data)?.path
            }.value
            self.selectedSkinPath = path
            self.updateHasChanges()
        }

        Logger.shared.info("Skin image dropped and processed successfully. Model: \(currentModel.rawValue)")
    }

    func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first,
                  url.startAccessingSecurityScopedResource() else { return }

            let urlForBackground = url
            Task {
                let data = await Task.detached(priority: .userInitiated) {
                    try? Data(contentsOf: urlForBackground)
                }.value
                urlForBackground.stopAccessingSecurityScopedResource()
                if let data = data {
                    self.processSkinData(data, filePath: urlForBackground.path)
                } else {
                    Logger.shared.error("Failed to read skin file")
                }
            }
        case .failure(let error):
            Logger.shared.error("File selection failed: \(error)")
        }
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
            guard let data = data else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let tempURL = await Task.detached(priority: .userInitiated) { () -> URL? in
                    let tempDir = FileManager.default.temporaryDirectory
                    let fileName = "temp_skin_\(UUID().uuidString).png"
                    let tempURL = tempDir.appendingPathComponent(fileName)
                    do {
                        try data.write(to: tempURL)
                        return tempURL
                    } catch {
                        Logger.shared.error("Failed to save temporary skin file: \(error)")
                        return nil
                    }
                }.value
                self.processSkinData(data, filePath: tempURL?.path)
            }
        }
        return true
    }

    func processSkinData(_ data: Data, filePath: String? = nil) {
        guard data.isPNG else { return }
        selectedSkinData = data
        selectedSkinImage = NSImage(data: data)
        selectedSkinPath = filePath
        updateHasChanges()
    }

    nonisolated func saveTempSkinFile(data: Data) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "temp_skin_\(UUID().uuidString).png"
        let tempURL = tempDir.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            Logger.shared.error("Failed to save temporary skin file: \(error)")
            return nil
        }
    }

    func clearSelectedSkin() {
        selectedSkinData = nil
        selectedSkinImage = nil
        selectedSkinPath = nil
        showingSkinPreview = false
        updateHasChanges()
    }
}
