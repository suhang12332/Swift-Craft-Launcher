import Foundation
import SwiftUI

@MainActor
final class ModPackExportSheetCoordinatorViewModel: ObservableObject {
    @Published var isExporting: Bool = false
    @Published var exportDocument: ModPackDocument?

    func prepareExportDocument(from tempFilePath: URL, onReadFailed: @escaping (String) -> Void) {
        Task {
            do {
                let fileData = try await Task.detached(priority: .userInitiated) {
                    try Data(contentsOf: tempFilePath)
                }.value

                self.exportDocument = ModPackDocument(data: fileData)
                self.isExporting = true
            } catch {
                onReadFailed(error.localizedDescription)
            }
        }
    }

    func cleanupExporterStateIfNeeded(oldValue: Bool, newValue: Bool) {
        if oldValue && !newValue && exportDocument != nil {
            exportDocument = nil
        }
    }

    func reset() {
        exportDocument = nil
        isExporting = false
    }
}
