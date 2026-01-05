import Foundation

// MARK: - EasyTier Download State
@MainActor
class EasyTierDownloadState: ObservableObject {
    @Published var isDownloading = false
    @Published var progress: Double = 0
    @Published var downloadedBytes: Int = 0
    @Published var totalBytes: Int = 0
    @Published var currentFile: String = ""
    @Published var isCancelled = false
    @Published var title: String = "EasyTier"
    @Published var errorMessage: String = ""
    @Published var hasError = false

    func reset() {
        isDownloading = false
        progress = 0
        downloadedBytes = 0
        totalBytes = 0
        currentFile = ""
        isCancelled = false
        title = "EasyTier"
        errorMessage = ""
        hasError = false
    }

    func startDownload() {
        self.title = "EasyTier"
        self.isDownloading = true
        self.progress = 0
        self.downloadedBytes = 0
        self.totalBytes = 0
        self.isCancelled = false
        self.hasError = false
        self.errorMessage = ""
    }

    func cancel() {
        isCancelled = true
    }

    func updateProgress(fileName: String, completed: Int, total: Int) {
        currentFile = fileName
        self.downloadedBytes = completed
        self.totalBytes = total
        self.progress = total > 0 ? Double(completed) / Double(total) : 0.0
    }

    func setError(_ message: String) {
        hasError = true
        errorMessage = message
        isDownloading = false
    }
}
